// SPDX-License-Identifier: UNLICENSED
// ref: https://ethereum.org/en/history
//  code size limit = 24576 bytes (a limit introduced in Spurious Dragon _ 2016)
//  code size limit = 49152 bytes (a limit introduced in Shanghai _ 2023)
// model ref: LUSDST.sol (081024)
// NOTE: uint type precision ...
//  uint8 max = 255
//  uint16 max = ~65K -> 65,535
//  uint32 max = ~4B -> 4,294,967,295
//  uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
pragma solidity ^0.8.24;

// import "./CallitTicket.sol"; // imports ERC20.sol // declares ICallitVault.deposit
import "./ICallConfig.sol";
import "./ICallLib.sol";

interface ISetConfig {
    function CONF_setConfig(address _conf) external;
}

contract CallConfig {
    /* _ ADMIN SUPPORT (legacy) _ */
    address public KEEPER;
    uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    mapping(address => bool) public ADMINS; // enable/disable admins (for promo support, etc)
    string public constant tVERSION = '0.0';
    address public ADDR_LIB = address(0x437dedd662736d6303fFB7ACd321966f4a81da3d); // CallitLib v0.0
    // address public ADDR_VAULT = address(0xc82D3e9Ed0B92EF0a6273090DC7F79EF2F53ACa4); // CallitVault v0.53
    // address public ADDR_DELEGATE = address(0xB4300bCdE9BE07B3057C36D1F05BBb8F0D0128b8); // CallitDelegate v0.50
    // address public ADDR_CALL = address(0x200F9C731c72Dce8974B28B52d39c20381efb37e); // CallitToken v0.21
    // address public ADDR_FACT = address(0x680F787373C173FA761cbCf9FbAbF94794a84180); // CallitFactory v0.68
    address public ADDR_VOTER = address(0x0C624cc578ab1871aEee20d08F792405060F787D); // CallitVoter v0.0
    address public ADDR_MARKET = address(0x0718a6271A36D5cc9Fc9cE3e994A0A64F9611EC0); // CallitMarket v0.0
    // address public ADDR_CONF = address(0xc5FB01Dea1e819bFcfF1690a2ffA493fDfeFae32); // CallitConfig v0.23

    ICallLib private LIB = ICallLib(ADDR_LIB);
    // ICallitToken private CALL = ICallitToken(ADDR_CALL);
    ICallMarket private MARKET = ICallMarket(ADDR_MARKET);


    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    // voting
    bool    public USE_SEC_DEFAULT_VOTE_TIME = true; // NOTE: false = use msg.sender's _secVoteTime in 'makerNewMarket'
    uint256 public SEC_DEFAULT_VOTE_TIME = 24 * 60 * 60; // 24 * 60 * 60 == 86,400 sec == 24 hours


    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
    /* -------------------------------------------------------- */
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(KEEPER).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _amount must be in uint precision to _erc20.decimals()
            require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(KEEPER, _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }
    function KEEPER_setKeeper(address _newKeeper, uint16 _keeperCheck) external onlyKeeper {
        require(_newKeeper != address(0), 'err: 0 address');
        // address prev = address(KEEPER);
        KEEPER = _newKeeper;
        if (_keeperCheck > 0)
            KEEPER_CHECK = _keeperCheck;
        // emit KeeperTransfer(prev, KEEPER);
    }
    function KEEPER_setContracts(address _lib, address _vault, address _delegate, address _CALL, address _fact, address _voter, address _mark, address _conf) external onlyKeeper {
        // EOA may indeed send 0x0 to "opt-in" for changing _conf address in support contracts
        //  if no _conf, update support contracts w/ current CONFIG address

        if (     _lib != address(0)) {ADDR_LIB = _lib; LIB = ICallLib(ADDR_LIB);}
        if (   _vault != address(0)) ADDR_VAULT = _vault;
        if (_delegate != address(0)) ADDR_DELEGATE = _delegate;
        if (    _CALL != address(0)) ADDR_CALL = _CALL;
        if (    _fact != address(0)) ADDR_FACT = _fact; 
        if (   _voter != address(0)) ADDR_VOTER = _voter;
        if (    _mark != address(0)) ADDR_MARKET = _mark; 
        if (    _conf == address(0)) _conf = address(this);

        // NOTE: make sure everything is done and set (above) before updating contract configs
        ISetConfig(ADDR_LIB).CONF_setConfig(_conf); // not in LIB
        // ISetConfig(ADDR_VAULT).CONF_setConfig(_conf);
        // ISetConfig(ADDR_DELEGATE).CONF_setConfig(_conf);
        // ISetConfig(ADDR_CALL).CONF_setConfig(_conf);
        // ISetConfig(ADDR_FACT).CONF_setConfig(_conf);
        // ISetConfig(ADDR_VOTER).CONF_setConfig(_conf);
        ISetConfig(ADDR_MARKET).CONF_setConfig(_conf);

        // reset configs used in this contract
        LIB = ICallLib(ADDR_LIB);
        // CALL = ICallitToken(ADDR_CALL);
        MARKET = ICallMarket(ADDR_CONFM);
    }

    function KEEPER_setMarketConfig(uint16 _maxResultOpts, uint64 _maxEoaMarkets, uint64 _minUsdArbTargPrice, uint256 _secDefaultVoteTime, bool _useDefaultVotetime) external {
        MAX_RESULTS = _maxResultOpts; // max # of result options a market may have
        MAX_EOA_MARKETS = _maxEoaMarkets;
        // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
        MIN_USD_CALL_TICK_TARGET_PRICE = _minUsdArbTargPrice;

        SEC_DEFAULT_VOTE_TIME = _secDefaultVoteTime; // 24 * 60 * 60 == 86,400 sec == 24 hours
        USE_SEC_DEFAULT_VOTE_TIME = _useDefaultVotetime; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    }
}