__fname = '_deploy_contract' # ported from 'defi-arb' (121023)
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

# CLI:
#   $ python3.10 _deploy_contract.py | tee ../bin/receipts/deploy_tBST_17_032424_2109.txt 
#------------------------------------------------------------#
#   IMPORTS                                                  #
#------------------------------------------------------------#
import sys, os, traceback, time, pprint, json
from datetime import datetime

# from web3 import Web3, HTTPProvider
# from web3.middleware import construct_sign_and_send_raw_middleware
# from web3.gas_strategies.time_based import fast_gas_price_strategy
# import env
import pprint
from attributedict.collections import AttributeDict # tx_receipt requirement
import _web3 # from web3 import Account, Web3, HTTPProvider

SELECT_DEPLOY_ALL = False
LST_CONTR_ABI_BIN = [
    # "../bin/contracts/CallitTicket", # deployed from CallitConfig
    "../bin/contracts/CallitLib",
    "../bin/contracts/CallitVault",
    "../bin/contracts/CallitDelegate",
    "../bin/contracts/CallitToken",
    "../bin/contracts/CallitFactory",
    "../bin/contracts/CallitVoter",
    "../bin/contracts/CallitMarket",
    "../bin/contracts/CallitConfig",
]

W3_ = None
ABI_FILE = None
BIN_FILE = None
CONTRACT = None

def init_web3_all():
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    # init W3_, user select abi to deploy, generate contract & deploy
    W3_ = _web3.myWEB3().init_inp()
    # lst_tup_abi_bin_path = []
    lst_contracts = []
    lst_contract_names = []
    lst_contract_file_paths = []
    print('*WARNING* detected SELECT_DEPLOY_ALL == True ...')
    print(' Gathering all ABIs & BINs to build all contracts in "LST_CONTR_ABI_BIN" ...')
    for i, v in enumerate(LST_CONTR_ABI_BIN): print(' ',i,'=',f'{v} _ {W3_.get_file_dt(v+".bin")}') # parse through tuple
    for i,v in enumerate(LST_CONTR_ABI_BIN):
        contr_name = LST_CONTR_ABI_BIN[i].split('/')[-1]
        # CallitConfig (bc i needs the addresses of the other)
        if contr_name == 'CallitConfig': 
            print('\nIGNORING CallitConfig ... just FYI ;) ')
            continue

        contract_ = W3_.add_contract_deploy(LST_CONTR_ABI_BIN[i]+'.abi', LST_CONTR_ABI_BIN[i]+'.bin')
        lst_contracts.append(contract_)
        lst_contract_names.append(contr_name)
        lst_contract_file_paths.append((LST_CONTR_ABI_BIN[i]+'.abi', LST_CONTR_ABI_BIN[i]+'.bin'))

    return lst_contracts, lst_contract_names, lst_contract_file_paths

def init_web3():
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    # init W3_, user select abi to deploy, generate contract & deploy
    W3_ = _web3.myWEB3().init_inp()
    ABI_FILE, BIN_FILE, idx_contr = W3_.inp_sel_abi_bin(LST_CONTR_ABI_BIN) # returns .abi|bin
    CONTRACT = W3_.add_contract_deploy(ABI_FILE, BIN_FILE)
    contr_name = LST_CONTR_ABI_BIN[idx_contr].split('/')[-1]
    return contr_name

def estimate_gas(contract, contract_args=[]):
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    # Replace with your contract's ABI and bytecode
    # contract_abi = CONTR_ABI
    # contract_bytecode = CONTR_BYTES
    
    # Replace with your wallet's private key
    private_key = W3_.SENDER_SECRET

    # Create a web3.py contract object
    # contract = W3_.W3.eth.contract(abi=contract_abi, bytecode=contract_bytecode)

    # Set the sender's address from the private key
    sender_address = W3_.W3.eth.account.from_key(private_key).address

    # Estimate gas for contract deployment
    # gas_estimate = contract.constructor().estimateGas({'from': sender_address})
    gas_estimate = contract.constructor(*contract_args).estimate_gas({'from': sender_address})

    print(f"\nEstimated gas cost _ 0: {gas_estimate}")

    import statistics
    block = W3_.W3.eth.get_block("latest", full_transactions=True)
    gas_estimate = int(statistics.median(t.gas for t in block.transactions))
    gas_price = W3_.W3.eth.gas_price
    gas_price_eth = W3_.W3.from_wei(gas_price, 'ether')
    print(f"Estimated gas cost _ 1: {gas_estimate}")
    print(f" Current gas price: {gas_price_eth} ether (PLS) == {gas_price} wei")
    # Optionally, you can also estimate the gas price (in Gwei) using a gas price strategy
    # Replace 'fast' with other strategies like 'medium' or 'slow' as needed
    #gas_price = W3.eth.generateGasPrice(fast_gas_price_strategy)
    #print(f"Estimated gas price (Gwei): {W3.fromWei(gas_price, 'gwei')}")
    
    return input('\n (3) procced? [y/n]\n  > ') == 'y'

# note: params checked/set in priority order; 'def|max_params' uses 'mpf_ratio'
#   if all params == False, falls back to 'min_params=True' (ie. just use 'gas_limit')
def get_gas_params_lst(rpc_url, min_params=False, max_params=False, def_params=True):
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    # Estimate the gas cost for the transaction
    #gas_estimate = buy_tx.estimate_gas()
    gas_limit = W3_.GAS_LIMIT # max gas units to use for tx (required)
    gas_price = W3_.GAS_PRICE # price to pay for each unit of gas (optional?)
    max_fee = W3_.MAX_FEE # max fee per gas unit to pay (optional?)
    max_prior_fee = W3_.MAX_PRIOR_FEE # max fee per gas unit to pay for priority (faster) (optional)
    #max_priority_fee = W3.to_wei('0.000000003', 'ether')

    if min_params:
        return [{'gas':gas_limit}]
    elif max_params:
        #return [{'gas':gas_limit}, {'gasPrice': gas_price}, {'maxFeePerGas': max_fee}, {'maxPriorityFeePerGas': max_prior_fee}]
        return [{'gas':gas_limit}, {'maxFeePerGas': max_fee}, {'maxPriorityFeePerGas': max_prior_fee}]
    elif def_params:
        return [{'gas':gas_limit}, {'maxPriorityFeePerGas': max_prior_fee}]
    else:
        return [{'gas':gas_limit}]

# def generate_contructor():
#     constr_args = []
#     print()
#     while True:
#         arg = input(' Add constructor arg (use -1 to end):\n  > ')
#         if arg == '-1': break
#         if arg.isdigit(): arg = int(arg)
#         constr_args.append(arg)
#     return constr_args

def main():
    import _keeper
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    contr_name = init_web3()
    tx_nonce = W3_.W3.eth.get_transaction_count(W3_.SENDER_ADDRESS)
    print(f'\nDEPLOYING bytecode: {BIN_FILE}')
    print(f'DEPLOYING abi: {ABI_FILE}')
    print(f'DEPLOYING w/ nonce: {tx_nonce}')
    assert input('\n (1) procced? [y/n]\n  > ') == 'y', "aborted...\n"

    # constr_args, = generate_contructor(f'{contr_name}.constructor(...)') # 0x78b48b71C8BaBd02589e3bAe82238EC78966290c
    constr_args, _ = _keeper.go_enter_func_params(f'{contr_name}.constructor(...)')
    
    print(f'  using "constructor({", ".join(map(str, constr_args))})"')
    assert input(f'\n (2) procced? [y/n] _ {get_time_now()}\n  > ') == 'y', "aborted...\n"

    # proceed = estimate_gas(CONTRACT, constr_args) # (3) proceed? [y/n]
    # assert proceed, "\ndeployment canceled after gas estimate\n"

    print('\ncalculating gas ...')
    # tx_nonce = W3_.W3.eth.get_transaction_count(W3_.SENDER_ADDRESS)
    tx_params = {
        'chainId': W3_.CHAIN_ID,
        'nonce': tx_nonce,
    }
    lst_gas_params = get_gas_params_lst(W3_.RPC_URL, min_params=False, max_params=True, def_params=True)
    for d in lst_gas_params: tx_params.update(d) # append gas params

    print(f'building tx w/ NONCE: {tx_nonce} ...')
    # constructor_tx = CONTRACT.constructor().build_transaction(tx_params)
    constructor_tx = CONTRACT.constructor(*constr_args).build_transaction(tx_params)

    print(f'signing and sending tx ... {get_time_now()}')
    # Sign and send the transaction # Deploy the contract
    tx_signed = W3_.W3.eth.account.sign_transaction(constructor_tx, private_key=W3_.SENDER_SECRET)
    tx_hash = W3_.W3.eth.send_raw_transaction(tx_signed.rawTransaction)

    print(cStrDivider_1, f'waiting for receipt ... {get_time_now()}', sep='\n')
    print(f'    tx_hash: {tx_hash.hex()}')

    # Wait for the transaction to be mined
    wait_time = 300 # sec
    try:
        tx_receipt = W3_.W3.eth.wait_for_transaction_receipt(tx_hash, timeout=wait_time)
        print("Transaction confirmed in block:", tx_receipt.blockNumber, f' ... {get_time_now()}')
    # except W3_.W3.exceptions.TransactionNotFound:    
    #     print(f"Transaction not found within the specified timeout... wait_time: {wait_time}", f' ... {get_time_now()}')
    # except W3_.W3.exceptions.TimeExhausted:
    #     print(f"Transaction not confirmed within the specified timeout... wait_time: {wait_time}", f' ... {get_time_now()}')
    except Exception as e:
        print(f"\n{get_time_now()}\n Transaction not confirmed within the specified timeout... wait_time: {wait_time}")
        print_except(e)
        exit(1)

    # print incoming tx receipt (requires pprint & AttributeDict)
    tx_receipt = AttributeDict(tx_receipt) # import required
    tx_rc_print = pprint.PrettyPrinter().pformat(tx_receipt)
    print(cStrDivider_1, f'RECEIPT:\n {tx_rc_print}', sep='\n')
    print(cStrDivider_1, f"\n\n Contract deployed at address: {tx_receipt['contractAddress']}\n\n", sep='\n')

def main_deploy_all():
    import _keeper
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    lst_constructor_tx = []
    lst_nonce_tx = []

    # select chain, read/init abis & bins, set gas, return contract list
    lst_contracts, lst_contr_names, lst_contract_file_paths = init_web3_all() 
    for i in range(0, len(lst_contracts)):
        tx_nonce = W3_.W3.eth.get_transaction_count(W3_.SENDER_ADDRESS) + i
        print(f'\nBUILDING...\n bytecode: {lst_contract_file_paths[i][1]}')
        print(f' abi: {lst_contract_file_paths[i][0]}')
        print(f' w/ nonce: {tx_nonce}')
        # assert input('\n (1) procced? [y/n]\n  > ') == 'y', "aborted...\n"

        # constr_args, = generate_contructor(f'{contr_name}.constructor(...)') # 0x78b48b71C8BaBd02589e3bAe82238EC78966290c
        constr_args, _ = _keeper.go_enter_func_params(f'{lst_contr_names[i]}.constructor(...)')
        
        print(f'  using "constructor({", ".join(map(str, constr_args))})"')
        # assert input(f'\n (2) procced? [y/n] _ {get_time_now()}\n  > ') == 'y', "aborted...\n"

        # proceed = estimate_gas(CONTRACT, constr_args) # (3) proceed? [y/n]
        # assert proceed, "\ndeployment canceled after gas estimate\n"

        print('\n calculating gas ...')
        # tx_nonce = W3_.W3.eth.get_transaction_count(W3_.SENDER_ADDRESS)
        tx_params = {
            'chainId': W3_.CHAIN_ID,
            'nonce': tx_nonce,
        }
        lst_gas_params = get_gas_params_lst(W3_.RPC_URL, min_params=False, max_params=True, def_params=True)
        for d in lst_gas_params: tx_params.update(d) # append gas params

        print(f' staging tx #{i} w/ NONCE: {tx_nonce} ...')
        # constructor_tx = CONTRACT.constructor().build_transaction(tx_params)
        constructor_tx = lst_contracts[i].constructor(*constr_args).build_transaction(tx_params)
        lst_constructor_tx.append(constructor_tx)
        lst_nonce_tx.append(tx_nonce)

    dict_contr_addr = {}
    for j in range(0, len(lst_constructor_tx)):
        print('', cStrDivider_1, f'SIGNING & SENDING tx #{j} ({lst_contr_names[j]}) _ w/ NONCE: {lst_nonce_tx[j]} ... {get_time_now()}', sep='\n')
        # Sign and send the transaction # Deploy the contract
        tx_signed = W3_.W3.eth.account.sign_transaction(lst_constructor_tx[j], private_key=W3_.SENDER_SECRET)
        tx_hash = W3_.W3.eth.send_raw_transaction(tx_signed.rawTransaction)

        print(cStrDivider_1, f'waiting for receipt ... {get_time_now()}', sep='\n')
        print(f'    tx_hash: {tx_hash.hex()}')

        # Wait for the transaction to be mined
        wait_time = 300 # sec
        try:
            tx_receipt = W3_.W3.eth.wait_for_transaction_receipt(tx_hash, timeout=wait_time)
            print("Transaction confirmed in block:", tx_receipt.blockNumber, f' ... {get_time_now()}')
        # except W3_.W3.exceptions.TransactionNotFound:    
        #     print(f"Transaction not found within the specified timeout... wait_time: {wait_time}", f' ... {get_time_now()}')
        # except W3_.W3.exceptions.TimeExhausted:
        #     print(f"Transaction not confirmed within the specified timeout... wait_time: {wait_time}", f' ... {get_time_now()}')
        except Exception as e:
            print(f"\n{get_time_now()}\n Transaction not confirmed within the specified timeout... wait_time: {wait_time}")
            print_except(e)
            # exit(1)
            continue

        # print incoming tx receipt (requires pprint & AttributeDict)
        tx_receipt = AttributeDict(tx_receipt) # import required
        tx_rc_print = pprint.PrettyPrinter().pformat(tx_receipt)
        print(cStrDivider_1, f'RECEIPT:\n {tx_rc_print}', sep='\n')
        print(cStrDivider_1, f"\n\n Contract deployed at address: {tx_receipt['contractAddress']}\n\n", sep='\n')

        dict_contr_addr[lst_contr_names[j]] = tx_receipt['contractAddress']

    print(cStrDivider_1, f'DEPLOYED CONTRACTS ...', cStrDivider_1, sep='\n')
    print(*(f"{key}: {val}" for key, val in dict_contr_addr.items()), sep='\n')
    print()

#------------------------------------------------------------#
#   DEFAULT SUPPORT                                          #
#------------------------------------------------------------#
READ_ME = f'''
    *DESCRIPTION*
        deploy contract to chain
         selects .abi & .bin from ../bin/contracts/

    *NOTE* INPUT PARAMS...
        nil
        
    *EXAMPLE EXECUTION*
        $ python3 {__filename} -<nil> <nil>
        $ python3 {__filename}
'''

#ref: https://stackoverflow.com/a/1278740/2298002
def print_except(e, debugLvl=0):
    #print(type(e), e.args, e)
    if debugLvl >= 0:
        print('', cStrDivider, f' Exception Caught _ e: {e}', cStrDivider, sep='\n')
    if debugLvl >= 1:
        print('', cStrDivider, f' Exception Caught _ type(e): {type(e)}', cStrDivider, sep='\n')
    if debugLvl >= 2:
        print('', cStrDivider, f' Exception Caught _ e.args: {e.args}', cStrDivider, sep='\n')
    if debugLvl >= 3:
        exc_type, exc_obj, exc_tb = sys.exc_info()
        fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
        strTrace = traceback.format_exc()
        print('', cStrDivider, f' type: {exc_type}', f' file: {fname}', f' line_no: {exc_tb.tb_lineno}', f' traceback: {strTrace}', cStrDivider, sep='\n')

def wait_sleep(wait_sec : int, b_print=True, bp_one_line=True): # sleep 'wait_sec'
    print(f'waiting... {wait_sec} sec')
    for s in range(wait_sec, 0, -1):
        if b_print and bp_one_line: print(wait_sec-s+1, end=' ', flush=True)
        if b_print and not bp_one_line: print('wait ', s, sep='', end='\n')
        time.sleep(1)
    if bp_one_line and b_print: print() # line break if needed
    print(f'waiting... {wait_sec} sec _ DONE')

def get_time_now(dt=True):
    if dt: return '['+datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[0:-4]+']'
    return '['+datetime.now().strftime("%H:%M:%S.%f")[0:-4]+']'

def read_cli_args():
    print(f'\nread_cli_args...\n # of args: {len(sys.argv)}\n argv lst: {str(sys.argv)}')
    for idx, val in enumerate(sys.argv): print(f' argv[{idx}]: {val}')
    print('read_cli_args _ DONE\n')
    return sys.argv, len(sys.argv)

if __name__ == "__main__":
    ## start ##
    RUN_TIME_START = get_time_now()
    print(f'\n\nRUN_TIME_START: {RUN_TIME_START}\n'+READ_ME)
    lst_argv_OG, argv_cnt = read_cli_args()
    
    ## exe ##
    try:
        SELECT_DEPLOY_ALL = input(' Deploy all contracts in "LST_CONTR_ABI_BIN"? [y/n]\n > ')
        SELECT_DEPLOY_ALL = SELECT_DEPLOY_ALL.lower() == 'y' or SELECT_DEPLOY_ALL == '1'
        if SELECT_DEPLOY_ALL:
            print(' *WARNING* detected SELECT_DEPLOY_ALL == True ...')
            main_deploy_all()
        else:
            main()
        
    except Exception as e:
        print_except(e, debugLvl=0)
    
    ## end ##
    print(f'\n\nRUN_TIME_START: {RUN_TIME_START}\nRUN_TIME_END:   {get_time_now()}\n')

print('', cStrDivider, f'# END _ {__filename}', cStrDivider, sep='\n')


# deploy log (082024):
# address public LIB_ADDR = address(0x657428d6E3159D4a706C00264BD0DdFaf7EFaB7e); // CallitLib v1.0
# address public VAULT_ADDR = address(0xAbF4E00b848E06bb11Df56f54e81B47D5A584e50); // CallitVault v0.1
# address public VAULT_ADDR = address(0xa8667527F00da10cadE9533952e069f5209273c2); // CallitVault v0.4
#       Gas Used / Limit: 5,497,528 / 12,000,000
# address public VAULT_ADDR = address(0xd6b7Fea23aD710037E3bA6b7850A8243Fb675eC2); // CallitVault v0.7
#       Gas Used / Limit: 5,378,694 / 25,000,000
#   GAS_LIMIT: 25,000,000 units
#   MAX_FEE: 200,000 beats
#   MAX_PRIOR_FEE: 24,000 beats
# address public LIB_ADDR = address(0x59183aDaF0bB8eC0991160de7445CC5A7c984f67); // CallitLib v0.4
# address public VAULT_ADDR = address(0xd6698958e15EBc21b1C947a94ad93c476492878a); // CallitVault v0.10
# address public DELEGATE_ADDR = address(0x2945E11a5645f9f4304D4356753f29D37dB2F656); // CallitDelegate v0.4
# address public CALL_ADDR = address(0x711DD234082fD5392b9DE219D7f5aDf03a857961); // CallitToken v0.3

# address public LIB_ADDR = address(0x59183aDaF0bB8eC0991160de7445CC5A7c984f67); // CallitLib v0.4
# address public VAULT_ADDR = address(0x03539AF4E8DC28E05d23FF97bB36e1578Fec6082); // CallitVault v0.12
# address public DELEGATE_ADDR = address(0xCEDaa5E3D2FFe1DA3D37BdD8e1AeF5D7B98BdcEB); // CallitDelegate v0.6
# address public CALL_ADDR = address(0xCbc5bC00294383a63551206E7b3276ABcf65CD33); // CallitToken v0.5

# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0x1E96e984B48185d63449d86Fb781E298Ac12FB49); // CallitVault v0.13
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0x26c7C431534b4E6b2bF1b9ebc5201bEf2f8477F5); // CallitVault v0.14
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0xb39EF1b589B4409e9EEE6BDd37c7C63c7095c41a); // CallitVault v0.15
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

#--------------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0xBA3ED9c7433CFa213289123f3b266D56141e674B); // CallitVault v0.16
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

#--------------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0x1985fF1eDa386e43224F6fAb3e5A8829911A3DFa); // CallitVault v0.19 (wiped)
# address public DELEGATE_ADDR = address(0x0061e3F653cEc349e52A516db992b1b2e8cC795F); // CallitDelegate v0.12
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xD85b3FE914BC1cE98f9e79C6ac847DA090ce709e); // CallitLib v0.7
# address public VAULT_ADDR = address(0xD3B393E6279ED74fC447292F80C41634ee0c1B6C); // CallitVault v0.20 (wiped)
# address public DELEGATE_ADDR = address(0xaFc6d7D0e4A4494b3c2FAad365fb5DEC0345eb6F); // CallitDelegate v0.13
# address public CALL_ADDR = address(0x781DebCbF5cb15fFF1944Fd6B1E8193365AE7046); // CallitToken v0.7
# address public FACT_ADDR = address(0x39327e074a2A65F6eE4bf9D3DdC89105eFe15e7E); // CallitFactory v0.19

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0x9c673684999f8432e53C0E8906c5a51Ab7a025c3); // CallitLib v0.8
# address public VAULT_ADDR = address(0xc98ef085E50C74083115E2EdC65416b846A079A6); // CallitVault v0.21 (wiped)
# address public DELEGATE_ADDR = address(0xB3a3602ae7A94852Cf1022250Ac6e5b21C51068b); // CallitDelegate v0.14
# address public CALL_ADDR = address(0x295862D4F7E13fd1981Bc22cB3a3c47180Da2358); // CallitToken v0.8
# address public FACT_ADDR = address(0xD4d9bA09DBB97889e7A15eCb7c1FeE8366ed3428); // CallitFactory v0.20

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xEf2ED160EfF99971804D4630e361D9B155Bc7c0E); // CallitLib v0.9
# address public VAULT_ADDR = address(0xc98ef085E50C74083115E2EdC65416b846A079A6); // CallitVault v0.21 (wiped)
# address public DELEGATE_ADDR = address(0xB3a3602ae7A94852Cf1022250Ac6e5b21C51068b); // CallitDelegate v0.14
# address public CALL_ADDR = address(0x295862D4F7E13fd1981Bc22cB3a3c47180Da2358); // CallitToken v0.8
# address public FACT_ADDR = address(0xD4d9bA09DBB97889e7A15eCb7c1FeE8366ed3428); // CallitFactory v0.20

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xEf2ED160EfF99971804D4630e361D9B155Bc7c0E); // CallitLib v0.9
# address public VAULT_ADDR = address(0x3B3fec46400885e766D5AFDCd74085db92608E1E); // CallitVault v0.22 (wiped)
# address public DELEGATE_ADDR = address(0x2E175DBC91c9a50424BF29A023E5eEDB47b6dB94); // CallitDelegate v0.15
# address public CALL_ADDR = address(0x628dF5Ec8885eDbf0D95e3702Ced54862EaA770c); // CallitToken v0.10
# address public FACT_ADDR = address(0x7683DF731Efc78708cDe3aa0B01089b13606358E); // CallitFactory v0.23

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xEf2ED160EfF99971804D4630e361D9B155Bc7c0E); // CallitLib v0.9
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23 (wiped)
# address public DELEGATE_ADDR = address(0x17E66C5629943AB17497bf56cc77A5FB83DbC565); // CallitDelegate v0.16
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x69F65544e92c7E099170a85078dfAcAF8381436d); // CallitFactory v0.24

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xAb2ce52Ed5C3952a1A36F17f2C7c59984866d753); // CallitLib v0.14
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23 (wiped)
# address public DELEGATE_ADDR = address(0x17E66C5629943AB17497bf56cc77A5FB83DbC565); // CallitDelegate v0.16
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x69F65544e92c7E099170a85078dfAcAF8381436d); // CallitFactory v0.24

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xAb2ce52Ed5C3952a1A36F17f2C7c59984866d753); // CallitLib v0.14
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23 (wiped)
# address public DELEGATE_ADDR = address(0x7c5A1eE5963e791018e2B4AcCD4E77dcC97a969F); // CallitDelegate v0.17
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x69F65544e92c7E099170a85078dfAcAF8381436d); // CallitFactory v0.24

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xAb2ce52Ed5C3952a1A36F17f2C7c59984866d753); // CallitLib v0.14
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23 (wiped)
# address public DELEGATE_ADDR = address(0x7c5A1eE5963e791018e2B4AcCD4E77dcC97a969F); // CallitDelegate v0.17
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x233d822548b71545d706Fe0Fef3796b58e9141A5); // CallitFactory v0.25

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public VAULT_ADDR = address(0x8f006f5aE5145d44E113752fA1cD5a40289efB70); // CallitVault v0.25 (wiped)
# address public DELEGATE_ADDR = address(0xcc884b22BE2D81D15c803aa47ff02f0a40A6Dd0D); // CallitDelegate v0.21
# address public CALL_ADDR = address(0xf5Ad4e325C9E953fc890C7f00b4DC2E16C56F533); // CallitToken v0.12
# address public FACT_ADDR = address(0xa72fcf6C1F9ebbBA50B51e2e0081caf3BCEa69aA); // CallitFactory v0.28

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public ADDR_VAULT = address(0xa967654c53F28281560589F89C61bAd0Dd6de3f0); // CallitVault v0.27 (wiped)
# address public ADDR_DELEGATE = address(0xcc884b22BE2D81D15c803aa47ff02f0a40A6Dd0D); // CallitDelegate v0.21
# address public ADDR_CALL = address(0xf5Ad4e325C9E953fc890C7f00b4DC2E16C56F533); // CallitToken v0.12
# address public ADDR_FACT = address(0x9e63042f71677da6fdB2D145cC96b62f134Df22E); // CallitFactory v0.30

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public ADDR_VAULT = address(0x4f7242cC8715f3935Ccec21012D32978e42C7763); // CallitVault v0.28 (wiped)
# address public ADDR_DELEGATE = address(0xD6380fc01f2eAD0725d71c87cd88e987b11D247B); // CallitDelegate v0.22
# address public ADDR_CALL = address(0x8Eb6d9c66104Ab29B0280687f7a483632A98d27D); // CallitToken v0.13
# address public ADDR_FACT = address(0x7E0Ed75F2217dD019E0D668e83Bc9E64Cd3246eb); // CallitFactory v0.31

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public ADDR_VAULT = address(0x15C49Ffd75998c04625Cb8d2d304416EdFb05387); // CallitVault v0.29 (wiped)
# address public ADDR_DELEGATE = address(0xD6380fc01f2eAD0725d71c87cd88e987b11D247B); // CallitDelegate v0.22
# address public ADDR_CALL = address(0x8Eb6d9c66104Ab29B0280687f7a483632A98d27D); // CallitToken v0.13
# address public ADDR_FACT = address(0x28AfD12D38CcE58863618bcED9c2753634325021); // CallitFactory v0.32

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public ADDR_VAULT = address(0x09258364a9B99814fb6c1C3fde75EDa902fb87d3); // CallitVault v0.30 (wiped)
# address public ADDR_DELEGATE = address(0xD6380fc01f2eAD0725d71c87cd88e987b11D247B); // CallitDelegate v0.22
# address public ADDR_CALL = address(0x8Eb6d9c66104Ab29B0280687f7a483632A98d27D); // CallitToken v0.13
# address public ADDR_FACT = address(0x28AfD12D38CcE58863618bcED9c2753634325021); // CallitFactory v0.32

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public ADDR_VAULT = address(0xE0665EdA947e8dEc9a2606Bf1262963A4c864817); // CallitVault v0.31 (wiped)
# address public ADDR_DELEGATE = address(0xD6380fc01f2eAD0725d71c87cd88e987b11D247B); // CallitDelegate v0.22
# address public ADDR_CALL = address(0x8Eb6d9c66104Ab29B0280687f7a483632A98d27D); // CallitToken v0.13
# address public ADDR_FACT = address(0x28AfD12D38CcE58863618bcED9c2753634325021); // CallitFactory v0.32

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public ADDR_VAULT = address(0xe727a3F8C658Fadf8F8c02111f2905E8b70D400f); // CallitVault v0.32 (wiped)
# address public ADDR_DELEGATE = address(0x3D876A96a1bBEe51de334386107a69977099A3C3); // CallitDelegate v0.23
# address public ADDR_CALL = address(0x8Eb6d9c66104Ab29B0280687f7a483632A98d27D); // CallitToken v0.13
# address public ADDR_FACT = address(0x28AfD12D38CcE58863618bcED9c2753634325021); // CallitFactory v0.32

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0x3348C10D210FA97fEaB3d8BDce76e2082D5DFF68); // CallitVault v0.33 (wiped)
# address public ADDR_DELEGATE = address(0xE30EC07f58886720864DAb308457446D31F8387a); // CallitDelegate v0.26
# address public ADDR_CALL = address(0x834958d81A3C6377BA958B87D0D9cf961f3415A2); // CallitToken v0.14
# address public ADDR_FACT = address(0x6A3e742839428DDDBbE458cAddF1a9336Ed68408); // CallitFactory v0.34
# address public ADDR_CONF = address(0xc4E8B856F18b230345e0713B71F7e2e8a6013cC2); // CallitConfig v0.2

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0xB6DC529fe5D39eB24d119F1a1C3f80DB3891B591); // CallitVault v0.34 (wiped)
# address public ADDR_DELEGATE = address(0x5C692a0F78E3a872C2bF8e02BC757D01E8747Edd); // CallitDelegate v0.27
# address public ADDR_CALL = address(0x834958d81A3C6377BA958B87D0D9cf961f3415A2); // CallitToken v0.14
# address public ADDR_FACT = address(0x09939F1E580D63923Fd8F86b815138996a7e9488); // CallitFactory v0.35
# address public ADDR_CONF = address(0xc4E8B856F18b230345e0713B71F7e2e8a6013cC2); // CallitConfig v0.2

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0x8d049b6528f02a3a6b1CDEa85545Cd6e3daD89b4); // CallitVault v0.35 (wiped)
# address public ADDR_DELEGATE = address(0xE894b4bC770EB147648770474e2e00565B40813e); // CallitDelegate v0.28
# address public ADDR_CALL = address(0x834958d81A3C6377BA958B87D0D9cf961f3415A2); // CallitToken v0.14
# address public ADDR_FACT = address(0x9cff91F5e06645235449e6a32CD2Ba923cA195ee); // CallitFactory v0.36
# address public ADDR_CONF = address(0x66096B7d4486ae3b464865c876fcDd67bA7996Fa); // CallitConfig v0.4

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0x23461333eFa55f1C9acf398bCC0c9F77e08E47aD); // CallitVault v0.36 (wiped)
# address public ADDR_DELEGATE = address(0xE5a78259cC87F3beA5b2aB4926Ce8c1fD7C728E6); // CallitDelegate v0.29
# address public ADDR_CALL = address(0x834958d81A3C6377BA958B87D0D9cf961f3415A2); // CallitToken v0.14
# address public ADDR_FACT = address(0x1E34609f60df8c64Da38061736360ae063fD2573); // CallitFactory v0.37
# address public ADDR_CONF = address(0x9F3686A8232aF59032A95A9D39dEce61509c1077); // CallitConfig v0.5

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0xaA633b73279e62Aa41727958E34b6349a09A7273); // CallitVault v0.37 (wiped)
# address public ADDR_DELEGATE = address(0xBd89dc747e8A7e68c88dFc691022Af5Ce419174e); // CallitDelegate v0.30
# address public ADDR_CALL = address(0x834958d81A3C6377BA958B87D0D9cf961f3415A2); // CallitToken v0.14
# address public ADDR_FACT = address(0x8c44426f7D4f13A2399413266166B256B7a739e5); // CallitFactory v0.38
# address public ADDR_CONF = address(0xEA154B3A1C494d17fe67a414a2e553849bbAE631); // CallitConfig v0.6

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0x6573695a9e82291d8AE4bEB1745c857e8d7cFfDa); // CallitVault v0.38 (wiped)
# address public ADDR_DELEGATE = address(0x36CFA0C1f5D452d3789F40eC7B064971CEDA476f); // CallitDelegate v0.31
# address public ADDR_CALL = address(0xe19Ab2d065340d12afc63F8FeE5a59b0b10b6846); // CallitToken v0.15
# address public ADDR_FACT = address(0xEd644dA69695e1E9FE1A6c5DA55CD7abB86D3346); // CallitFactory v0.39
# address public ADDR_CONF = address(0xca34871d0bb8C62068F4A83242bCA3c4Bde62eC5); // CallitConfig v0.7

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0x35043eA36cEd4a5D9586682A6A178452267AFF20); // CallitVault v0.39 (wiped)
# address public ADDR_DELEGATE = address(0x36CFA0C1f5D452d3789F40eC7B064971CEDA476f); // CallitDelegate v0.31
# address public ADDR_CALL = address(0xe19Ab2d065340d12afc63F8FeE5a59b0b10b6846); // CallitToken v0.15
# address public ADDR_FACT = address(0xEd644dA69695e1E9FE1A6c5DA55CD7abB86D3346); // CallitFactory v0.39
# address public ADDR_CONF = address(0x89f252Afb43cb5a4eB57de37Bc281A33D3b6DBB1); // CallitConfig v0.8

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0xA95a56811d62acb2040Ded1D7d264582098d2411); // CallitVault v0.40
# address public ADDR_DELEGATE = address(0x36CFA0C1f5D452d3789F40eC7B064971CEDA476f); // CallitDelegate v0.31
# address public ADDR_CALL = address(0xe19Ab2d065340d12afc63F8FeE5a59b0b10b6846); // CallitToken v0.15
# address public ADDR_FACT = address(0xEd644dA69695e1E9FE1A6c5DA55CD7abB86D3346); // CallitFactory v0.39
# address public ADDR_CONF = address(0x89f252Afb43cb5a4eB57de37Bc281A33D3b6DBB1); // CallitConfig v0.8

#-----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0x42eb4165c1cA5D30e69ADb347CA3C97E74009147); // CallitVault v0.41 (wiped)
# address public ADDR_DELEGATE = address(0x36CFA0C1f5D452d3789F40eC7B064971CEDA476f); // CallitDelegate v0.31
# address public ADDR_CALL = address(0xe19Ab2d065340d12afc63F8FeE5a59b0b10b6846); // CallitToken v0.15
# address public ADDR_FACT = address(0xEd644dA69695e1E9FE1A6c5DA55CD7abB86D3346); // CallitFactory v0.39
# address public ADDR_CONF = address(0x89f252Afb43cb5a4eB57de37Bc281A33D3b6DBB1); // CallitConfig v0.8

# -----------------------------------------------------------------------------------------------------------#
# address public ADDR_LIB = address(0x8FF7c05259725209Fa7dA5038eD4E1DaB37710C9); // CallitLib v0.16
# address public ADDR_VAULT = address(0x174Bf1B8fc100A6cb2d5430075E5B340c61Dcb15); // CallitVault v0.42
# address public ADDR_DELEGATE = address(0x36CFA0C1f5D452d3789F40eC7B064971CEDA476f); // CallitDelegate v0.31
# address public ADDR_CALL = address(0xe19Ab2d065340d12afc63F8FeE5a59b0b10b6846); // CallitToken v0.15
# address public ADDR_FACT = address(0xEd644dA69695e1E9FE1A6c5DA55CD7abB86D3346); // CallitFactory v0.39
# address public ADDR_CONF = address(0x89f252Afb43cb5a4eB57de37Bc281A33D3b6DBB1); // CallitConfig v0.8


# 12329396971491629054
#  4109798000000000000
#-----------------------------------------------------------------------------------------------------------#
# 0x0000000000000000000000000000000000000000
# address public ADDR_LIB = address(); // CallitLib v0.15
# address public ADDR_VAULT = address(); // CallitVault v0.27
# address public ADDR_DELEGATE = address(); // CallitDelegate v0.21
# address public ADDR_CALL = address(); // CallitToken v0.12
# address public ADDR_FACT = address(); // CallitFactory v0.30


#-----------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(); // CallitLib v0.7
# address public VAULT_ADDR = address(); // CallitVault v0.20
# address public DELEGATE_ADDR = address(); // CallitDelegate v0.13
# address public CALL_ADDR = address(); // CallitToken v0.7
# address public FACT_ADDR = address(); // CallitFactory v0.19


#--------------------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------------------#
# tmark_0 1029945 1724958296 1724959296 1724960296 ["tl_1", "tl_2", "tl_2"] ["td_1", "td_2", "td_2"]
# tmark_0 1029945 1724958296 1724959296 1724960296 ["tl_1","tl_2","tl_2"] ["td_1","td_2","td_2"]
# tmark_0 1029945 1724958296 1724959296 1724960296 [tl_1,tl_2,tl_2] [td_1,td_2,td_2]
# tmark_0 1029945 1724958296 1724959296 1724960296 [0xtl_1,0xtl_2,0xtl_2] [0xtd_1,0xtd_2,0xtd_2]
# tmark_0
# 1039332
# 1693191781
# 1693192781
# 1693193781
# ["tl_1", "tl_2", "tl_3"]
# ["td_1", "td_2", "td_3"]

# 0x0000000000000000000000000000000000000369
# 0x0000000000000000000000000000000000000000

# atropa mint puzzles cracked (end 2023)
# '0x1f737F7994811fE994Fe72957C374e5cD5D5418A' # ⑨ (テディベア) - TeddyBear9
# '0x4C1518286E1b8D5669Fe965EF174B8B4Ae2f017B' # Annabelle: The Profit ㉶ _ (BEL ㉶)
# '0x25d53961a27791B9D8b2d74FB3e937c8EAEadc38' # ⑦ _ BOND
# '0x2959221675bdF0e59D0cC3dE834a998FA5fFb9F4' # ⑧ (BULLION ⑧) _ BUL8
# '0xA537d6F4c1c8F8C41f1004cc34C00e7Db40179Cc' # 问题 (问题) _ wenti
# '0x26D5906c4Cdf8C9F09CBd94049f99deaa874fB0b' # ހް (ޖޮޔިސްދޭވޯހީ) _ writing