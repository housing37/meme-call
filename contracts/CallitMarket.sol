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

import './ICallitConfig.sol';
import './ICallitVault.sol';

interface IERC20 {
    function transfer(address _to, uint256 _amount) external;
    function balanceOf(address _account) external view returns(uint256);
    function decimals() external pure returns (uint8);
}
interface ICallitToken {
    function ACCT_CALL_VOTE_LOCK_TIME(address _key) external view returns(uint256); // public
    function EARNED_CALL_VOTES(address _key) external view returns(uint64); // public
    // function mintCallToksEarned(address _receiver, uint256 _callAmntMint, uint64 _callVotesEarned, address _sender) external;
    // function decimals() external pure returns (uint8);
    function balanceOf_voteCnt(address _voter) external view returns(uint64);

    // function initVoterHashForAcct(address _acct) external;
    // function getVoterHashForAcct(address _acct) external view returns(address);
}
// interface IERC20x {
//     function decimals() external pure returns (uint8);
//     function approve(address spender, uint256 value) external returns (bool);
// }
contract CallitMarket {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    /* GLOBALS (CALLIT) */
    string public tVERSION = '0.6';
    bool private FIRST_ = true;
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    ICallitVoter private VOTER; // set via CONF_setConfig
    ICallitLib private LIB;     // set via CONF_setConfig
    ICallitVault private VAULT; // set via CONF_setConfig
    // ICallitDelegate private DELEGATE; // set via CONF_setConfig
    ICallitToken private CALL;  // set via CONF_setConfig

    /* _ ACCOUNT SUPPORT (legacy) _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    // NOTE: legacy public
    mapping(address => uint64) public ACCT_USD_BALANCES; 
    address[] public ACCOUNTS; // NOTE: private is more secure; consider external KEEPER getter instead
    mapping(address => address) public TICK_PAIR_ADDR; // used for lp maintence KEEPER withdrawel
    address[] public LIVE_TICKETS_LST;
    // mapping(address => uint64) public PROMO_USD_OWED; // maps promo code HASH to usd owed for that hash
    // mapping(address => ICallitLib.PROMO) public HASH_PROMO; // store promo code hashes to their PROMO mapping
    // mapping(address => ICallitLib.MARKET_REVIEW[]) private ACCT_MARKET_REVIEWS; // store maker to all their MARKET_REVIEWs created by callers

    // NOTE: a copy of all MARKET in ICallitLib.MARKET[] is stored in DELEGATE (via ACCT_MARKET_HASHES -> HASH_MARKET)
    //  ie. ACCT_MARKETS[_maker][0] == HASH_MARKET[ACCT_MARKET_HASHES[_maker][0]]
    //      HENCE, always -> ACCT_MARKETS.length == ACCT_MARKET_HASHES.length
    // mapping(address => ICallitLib.MARKET[]) public ACCT_MARKETS; // store maker to all their MARKETs created mapping ***
    // NOTE: aut-generated mapping getters will include idx param for arrays 
    //          & return data inside structs (not the struct itself)
    //  ref: https://docs.soliditylang.org/en/v0.8.0/contracts.html#getter-functions
    //  ref: https://docs.soliditylang.org/en/v0.8.0/types.html#mappings
    // mapping(address => ICallitLib.MARKET_VOTE[]) private ACCT_MARKET_VOTES; // store voter to their non-paid MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & private until market close; live = false) ***
    // mapping(address => ICallitLib.MARKET_VOTE[]) public ACCT_MARKET_VOTES_PAID; // store voter to their 'paid' MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & avail when market close; live = false) *
    mapping(string => address[]) private CATEGORY_MARK_HASHES; // store category to list of market hashes
    mapping(address => address[]) private ACCT_MARKET_HASHES; // store maker to list of market hashes
    mapping(address => ICallitLib.MARKET) public HASH_MARKET; // store market hash to its MARKET
    mapping(address => address) public TICKET_MAKER; // store ticket to their MARKET.maker mapping
    address[] public MARKET_HASH_LST; // store list of all market haches

    // *WARNING* -> re-deploy means wiping promo & vote data & account handles
    // promo data storage
    mapping(address => uint64) public PROMO_USD_OWED; // maps promo code HASH to usd owed for that hash
    mapping(address => ICallitLib.PROMO) public HASH_PROMO; // store promo code hashes to their PROMO mapping
    mapping(address => address[]) public PROMOTOR_HASHES; // map promo code list to their promotor

    // market makers (etc.) can set their own handles
    mapping(address => string) public ACCT_HANDLES;

    // // NOTE: required for voter hash algorithm (all need to be in the same contract)
    // mapping(address => uint64[]) private MARK_HASH_RESULT_VOTES; // store market hash to result vote counts array (ie. keep private then set MARKET resultTokenVotes after close);
    // mapping(address => address) private ACCT_VOTER_HASH; // address hash used for generating _senderTicketHash in FACT.castVoteForMarketTicket
    // uint64 private LIVE_TICKET_COUNT; // uint64 = max 18,000Q live tickets it can account for // CONFM set during LIVE_TICKETS_LST updates

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */


    /* -------------------------------------------------------- */
    /* CONSTRUCTOR
    /* -------------------------------------------------------- */
    constructor() {

    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == CONF.KEEPER(), "!keeper :p");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.ADDR_DELEGATE() || msg.sender == CONF.KEEPER(), " !keeper & !fact :p");
        _;
    }
    modifier onlyVault {
        require(msg.sender == CONF.ADDR_VAULT() || msg.sender == CONF.ADDR_DELEGATE() || msg.sender == CONF.KEEPER(), ' only vault :0 ');
        _;
    }
    modifier onlyConfig() { 
        // allows 1st onlyConfig attempt to freely pass
        //  NOTE: don't waste this on anything but CONF_setConfig
        if (!FIRST_) 
            require(msg.sender == address(CONF), ' !CONF :/ ');
        FIRST_ = false;
        _;
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :< ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(ADDR_CONFIG);
        VOTER = ICallitVoter(CONF.ADDR_VOTER());
        LIB = ICallitLib(CONF.ADDR_LIB());
        VAULT = ICallitVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
        // DELEGATE = ICallitDelegate(CONF.ADDR_DELEGATE());
        CALL = ICallitToken(CONF.ADDR_CALL());
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER setters
    /* -------------------------------------------------------- */
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(CONF.KEEPER()).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _amount must be in uint precision to _erc20.decimals()
            require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(CONF.KEEPER(), _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - MUTATORS
    /* -------------------------------------------------------- */
    function getPromoForHash(address _promoHash) external view returns(ICallitLib.PROMO memory) {
        require(_promoHash != address(0), ' no hash :/ ');
        return HASH_PROMO[_promoHash];
    }
    function getPromoHashesForAcct(address _acct) external view returns(address[] memory) {
        require(_acct != address(0) && PROMOTOR_HASHES[_acct].length > 0, ' no _acct :/ ');
        return PROMOTOR_HASHES[_acct];
    }
    function setPromoForHash(address _promoHash, ICallitLib.PROMO memory _promo) external onlyFactory {
        require(_promo.promotor != address(0) && _promoHash != address(0), ' no promo|hash :/ ');
        HASH_PROMO[_promoHash] = _promo;
        PROMOTOR_HASHES[_promo.promotor].push(_promoHash);
    }
    function setUsdOwedForPromoHash(uint64 _usdOwed, address _promoCodeHash) external onlyVault {
        PROMO_USD_OWED[_promoCodeHash] = _usdOwed;
    }
    function setAcctHandle(address _sender, string calldata _handle) external onlyFactory {
        require(_sender != address(0) && bytes(_handle).length >= 2 && bytes(_handle)[0] != 0x20, ' !_handle :[] ');
        if (LIB._validNonWhiteSpaceString(_handle))
            ACCT_HANDLES[_sender] = _handle;
        else
            revert(' !blank space handles :-[=] ');     
    }
    // function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) private {
    function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) external onlyVault {
        if (_add) {
            require(_usdAmnt > 0, ' !add 0 :/ ' );
            ACCT_USD_BALANCES[_acct] += _usdAmnt;
            ACCOUNTS = LIB._addAddressToArraySafe(_acct, ACCOUNTS, true); // true = no dups
        } else {
            require(ACCT_USD_BALANCES[_acct] >= _usdAmnt, ' !deduct low balance :{} ');
            ACCT_USD_BALANCES[_acct] -= _usdAmnt;    
        }
    }
    function editLiveTicketList(address _ticket, address  _pairAddr, bool _add) external onlyVault {
        if (_add) {
            TICK_PAIR_ADDR[_ticket] = _pairAddr;
            LIVE_TICKETS_LST = LIB._addAddressToArraySafe(_ticket, LIVE_TICKETS_LST, true); // true = no dups
        } else {
            LIVE_TICKETS_LST = LIB._remAddressFromArray(_ticket, LIVE_TICKETS_LST);
        }
        VOTER.set_LIVE_TICKET_COUNT(LIB._uint64_from_uint256(LIVE_TICKETS_LST.length));
    }
    function storeNewMarket(ICallitLib.MARKET memory _mark, address _maker) external onlyFactory {
        require(_maker != address(0) && _mark.marketHash != address(0), ' bad maker | hash :*{ ');
        ACCT_MARKET_HASHES[_maker].push(_mark.marketHash);
        HASH_MARKET[_mark.marketHash] = _mark;
        MARKET_HASH_LST.push(_mark.marketHash);
    }
    function setHashMarket(address _markHash, ICallitLib.MARKET memory _mark, string calldata _category) external onlyFactory {
        require(_markHash != address(0), ' bad hash :*{ ');
        HASH_MARKET[_markHash] = _mark;
        if (bytes(_category).length > 1) CATEGORY_MARK_HASHES[_category].push(_markHash);
    }
    function setMakerForTickets(address _maker, address[] memory _tickets) external onlyFactory {
        require(_tickets.length > 0 && _maker != address(0), ' bad _maker|_ticket :/ ');
        // Loop through _resultLabels and log deployed ERC20s tickets into TICKET_MAKER mapping
        for (uint16 i = 0; i < _tickets.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // set ticket to maker mapping (additional access support)
            TICKET_MAKER[_tickets[i]] = _maker;
            unchecked {i++;}
        }
    }
    // function setPromoForHash(address _promoHash, ICallitLib.PROMO memory _promo) external {
    //     require(_promo.promotor != address(0) && _promoHash != address(0), ' no promo|hash :/ ');
    //     HASH_PROMO[_promoHash] = _promo;
    // }
    // function setUsdOwedForPromoHash(uint64 _usdOwed, address _promoCodeHash) external onlyVault {
    //     PROMO_USD_OWED[_promoCodeHash] = _usdOwed;
    // }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    function getLiveTicketCnt() external view returns(uint256) {
        return LIVE_TICKETS_LST.length;
    }
    function getLiveTickets() external view returns(address[] memory) {
        return LIVE_TICKETS_LST;
    }
    function owedStableBalance() external view onlyVault returns (uint64) {
        uint64 owed_bal = 0;
        for (uint256 i = 0; i < ACCOUNTS.length;) {
            owed_bal += ACCT_USD_BALANCES[ACCOUNTS[i]];
            unchecked {i++;}
        }
        return owed_bal;
    }
    function getAccounts() external view returns (address[] memory) {
        return ACCOUNTS;
    }
    // function getPomoForHash(address _promoHash) external view returns(ICallitLib.PROMO memory) {
    //     require(_promoHash != address(0), ' no hash :/ ');
    //     return HASH_PROMO[_promoHash];
    // }
    // function getMakerForTicket(address _ticket) external view returns(address) {
    //     require(_ticket != address(0), ' !_maker ;() ');
    //     return TICKET_MAKER[_ticket];
    // }
    // function getMarketForHash(address _hash) external view returns(ICallitLib.MARKET memory) {
    function getMarketForHash(address _hash) public view returns(ICallitLib.MARKET memory) {
        ICallitLib.MARKET memory mark = HASH_MARKET[_hash];
        require(mark.maker != address(0), ' !maker :0 ');
        return mark;
    }
    function getMarketHashesForMakerOrCategory(address _maker, string calldata _category) external view returns(address[] memory) {
        if (bytes(_category).length > 1) { // note: sending a single 'space', signals use _maker
            require(CATEGORY_MARK_HASHES[_category].length > 0, ' no _cat market :/ ');
            return CATEGORY_MARK_HASHES[_category];
        } else if (_maker != address(0)) {
            require(ACCT_MARKET_HASHES[_maker].length > 0, ' no _maker markets :/ ');
            return ACCT_MARKET_HASHES[_maker];
        } else {
            require(MARKET_HASH_LST.length > 0, ' no markets :/ ');
            return MARKET_HASH_LST;
        }
    }
    function getMarketCntForMaker(address _maker) external view returns(uint256) {
        // NOTE: MAX_EOA_MARKETS is uint64
        return ACCT_MARKET_HASHES[_maker].length;
    }
    function _getMarketForTicket(address _ticket) external view returns(ICallitLib.MARKET memory, uint16, address) {
        require(_ticket != address(0), ' no address for market ;:[=] ');

        // NOTE: MAX_EOA_MARKETS is uint64
        // address _maker = TICKET_MAKER[_ticket];
        address[] memory mark_hashes = ACCT_MARKET_HASHES[TICKET_MAKER[_ticket]];
        for (uint64 i = 0; i < mark_hashes.length;) {
            ICallitLib.MARKET memory mark = HASH_MARKET[mark_hashes[i]];
            for (uint16 x = 0; x < mark.marketResults.resultOptionTokens.length;) {
                if (mark.marketResults.resultOptionTokens[x] == _ticket)
                    return (mark, x, mark_hashes[i]);
                    // return mark;
                unchecked {x++;}
            }   
            unchecked {
                i++;
            }
        }
        
        revert(' market not found :( ');
    }
}