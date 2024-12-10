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

import './ICallConfig.sol';
// import './ICallitVault.sol';

contract CallMarket {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    /* GLOBALS (CALLIT) */
    string public tVERSION = '0.6';
    bool private FIRST_ = true;
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallConfig private CONF; // set via CONF_setConfig
    // ICallitVoter private VOTER; // set via CONF_setConfig
    // ICallitLib private LIB;     // set via CONF_setConfig
    // ICallitVault private VAULT; // set via CONF_setConfig
    // ICallitDelegate private DELEGATE; // set via CONF_setConfig
    // ICallitToken private CALL;  // set via CONF_setConfig


    // NOTE: aut-generated mapping getters will include idx param for arrays 
    //          & return data inside structs (not the struct itself)
    //  ref: https://docs.soliditylang.org/en/v0.8.0/contracts.html#getter-functions
    //  ref: https://docs.soliditylang.org/en/v0.8.0/types.html#mappings
    mapping(string => address[]) private CATEGORY_MARK_HASHES; // store category to list of market hashes
    mapping(address => address[]) private ACCT_MARKET_HASHES; // store maker to list of market hashes
    mapping(address => ICallitLib.MARKET) public HASH_MARKET; // store market hash to its MARKET
    address[] public MARKET_HASH_LST; // store list of all market haches

    // market makers (etc.) can set their own handles
    mapping(address => string) public ACCT_HANDLES;

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
        CONF = ICallConfig(ADDR_CONFIG);
        // VOTER = ICallitVoter(CONF.ADDR_VOTER());
        // LIB = ICallitLib(CONF.ADDR_LIB());
        // VAULT = ICallitVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
        // // DELEGATE = ICallitDelegate(CONF.ADDR_DELEGATE());
        // CALL = ICallitToken(CONF.ADDR_CALL());
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - UI accessors
    /* -------------------------------------------------------- */
    function getMarketCntForMaker(address _maker) external view returns(uint256) {
        // NOTE: MAX_EOA_MARKETS is uint64
        return ACCT_MARKET_HASHES[_maker].length;
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

    /* -------------------------------------------------------- */
    /* PUBLIC - admin mutators
    /* -------------------------------------------------------- */
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
}