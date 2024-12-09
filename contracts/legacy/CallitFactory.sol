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

// inherited contracts
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

// local _ $ npm install @openzeppelin/contracts
// import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./ICallitVault.sol"; // imports ICallitLib.sol
import "./ICallitConfig.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external returns(uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function decimals() external pure returns (uint8);
}
interface ICallitToken {
    // function ACCT_CALL_VOTE_LOCK_TIME(address _key) external view returns(uint256); // public
    // function EARNED_CALL_VOTES(address _key) external view returns(uint64); // public
    function mintCallToksEarned(address _receiver, uint256 _callAmntMint, uint64 _callVotesEarned, address _sender) external;
    function decimals() external pure returns (uint8);
    function pushAcctMarketReview(ICallitLib.MARKET_REVIEW memory _marketReview, address _maker) external;
    function getMarketReviewsForMaker(address _maker) external view returns(ICallitLib.MARKET_REVIEW[] memory);
}
interface ICallitTicket {
    function burnForRewardClaim(address _account) external;
    function decimals() external pure returns (uint8);
    function setDeadlineTransferLock(bool _lock) external;
}
interface ICallitDelegate {
    function makeNewMarket( string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                        uint64 _usdAmntLP, 
                        uint256 _dtCallDeadline, 
                        uint256 _dtResultVoteStart, 
                        uint256 _dtResultVoteEnd, 
                        string[] calldata _resultLabels, // note: could possibly remove to save memory (ie. removed _resultDescrs succcessfully)
                        uint256 _mark_num,
                        address _sender
                        ) external returns(ICallitLib.MARKET memory);
    function buyCallTicketWithPromoCode(address _usdStableResult, address _ticket, address _promoCodeHash, uint64 _usdAmnt, address _reciever) external returns(uint64, uint256);
    function closeMarketCalls(ICallitLib.MARKET memory mark) external returns(uint64);
    function claimVoterRewards() external;
}

contract CallitFactory {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    /* GLOBALS (CALLIT) */
    string public tVERSION = '0.74';
    bool private FIRST_ = true;
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    ICallitMarket private CONFM; // set via CONF_setConfig
    ICallitVoter private VOTER; // set via CONF_setConfig
    ICallitLib private LIB;     // set via CONF_setConfig
    ICallitVault private VAULT; // set via CONF_setConfig
    ICallitDelegate private DELEGATE; // set via CONF_setConfig
    ICallitToken private CALL;  // set via CONF_setConfig
    uint64 private CALL_INIT_MINT;
    
    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    event MarketCreated(address _maker, uint256 _markNum, address _markHash, string _name, uint64 _usdAmntLP, uint256 _dtCallDeadline, uint256 _dtResultVoteStart, uint256 _dtResultVoteEnd, string[] _resultLabels, address[] _resultOptionTokens, uint256 _blockTime, bool _live);
    event PromoBuyPerformed(address _buyer, address _promoCodeHash, address _usdStable, address _ticket, uint64 _grossUsdAmnt, uint64 _netUsdAmnt, uint256  _tickAmntOut, uint64 _callEarnedAmnt);
    event MarketReviewed(address _caller, bool _resultAgree, address _marketMaker, uint256 _marketNum, address _markHash, uint64 _agreeCnt, uint64 _disagreeCnt);
    event ArbPriceCorrectionExecuted(address _executer, address _ticket, uint64 _tickTargetPrice, uint64 _tokenMintCnt, uint64 _usdGrossReceived, uint64 _usdTotalPaid, uint64 _usdNetProfit, uint64 _callEarnedAmnt);
    event MarketCallsClosed(address _executer, address _ticket, address _marketMaker, uint256 _marketNum, address _markHash, uint64 _usdAmntPrizePool, uint64 _callEarnedAmnt);
    event MarketClosed(address _sender, address _ticket, address _marketMaker, uint256 _marketNum, address _markHash, uint64 _winningResultIdx, uint64 _usdPrizePoolPaid, uint64 _usdVoterRewardPoolPaid, uint64 _usdRewardPervote, uint64 _callEarnedAmnt);
    event TicketRewardsClaimed(address _sender, address _ticket, bool _is_winner, bool _resultAgree);

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR
    /* -------------------------------------------------------- */
    constructor(uint64 _CALL_initSupply) {
        CALL_INIT_MINT = _CALL_initSupply;
        // NOTE: CALL initSupply is minted to KEEPER via CONF_setConfig init call (ie. _mintCallToksEarned)
        // NOTE: whitelist stable & dex routers set in CONF constructor
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
        if (!FIRST_) {
            require(msg.sender == address(CONF), ' !CONF :p '); // first validate CONF
            _; // then proceed to set CONF++
        } else {
            _; // first proceed to set CONF++
            _mintCallToksEarned(CONF.KEEPER(), CALL_INIT_MINT); // then mint CALL to keeper
            FIRST_ = false; // never again
        } 
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :< ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(ADDR_CONFIG);
        CONFM = ICallitMarket(CONF.ADDR_CONFM());
        VOTER = ICallitVoter(CONF.ADDR_VOTER());
        LIB = ICallitLib(CONF.ADDR_LIB());
        VAULT = ICallitVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
        DELEGATE = ICallitDelegate(CONF.ADDR_DELEGATE());
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
    /* PUBLIC - UI (CALLIT)
    /* -------------------------------------------------------- */
    function getMarketForTicket(address _ticket) external view returns(ICallitLib.MARKET memory) {
        (ICallitLib.MARKET memory mark,,) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        return mark;
    }
    function getMarketForHash(address _hash) external view returns(ICallitLib.MARKET memory) {
        return CONFM.getMarketForHash(_hash); // checks require
    }
    function getPromosForAcct(address _acct) external view returns(ICallitLib.PROMO[] memory) {
        address[] memory promoHashes = CONFM.getPromoHashesForAcct(_acct); // checks require on _acct & length > 0
        ICallitLib.PROMO[] memory ret_promos = new ICallitLib.PROMO[](promoHashes.length);
        for (uint64 i=0; i < promoHashes.length;) {
            ret_promos[i] = CONFM.getPromoForHash(promoHashes[i]);
            unchecked { i++; }
        }

        require(ret_promos[0].promotor != address(0), ' no promos found :// ');
        return ret_promos;
    }
    function getMarketCntForMakerOrCategory(address _maker, string calldata _category) external view returns(uint256) {
        // NOTE: MAX_EOA_MARKETS is uint64
        address[] memory mark_hashes = CONFM.getMarketHashesForMakerOrCategory(_maker, _category); // note: checks for _category.length > 1
        return mark_hashes.length;
    }
    function getMarketHashesForMakerOrCategory(string calldata _category, address _maker, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) external view returns(address[] memory) {
        // require(_maker != address(0), ' !_maker ;[=] '); // 
        address[] memory mark_hashes = CONFM.getMarketHashesForMakerOrCategory(_maker, _category); // note: checks for _category.length > 1 & _maker != address(0)
        require(mark_hashes.length > 0 && _retCnt > 0 && mark_hashes.length >= _idxStart + _retCnt, ' out of range :p ');
        address[] memory ret_hashes = new address[](_retCnt);
        uint8 cnt_;
        for (uint8 i = 0; cnt_ < _retCnt && _idxStart + i < mark_hashes.length;) {
            // check for mismatch, skip & inc only 'i' (note: _all == _live|!_live)
            ICallitLib.MARKET memory mark = CONFM.getMarketForHash(mark_hashes[_idxStart + i]);
            if (!_all && mark.live != _live) { 
                unchecked {i++;} 
                continue; 
            }

            // log market hash found; continue w/ inc both 'i' & 'cnt_'
            ret_hashes[cnt_] = mark_hashes[_idxStart + i];
            unchecked {
                i++; cnt_++;
            }
        }
        return ret_hashes;
    }
    function getMarketsForMakerOrCategory(string calldata _category, address _maker, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) external view returns(ICallitLib.MARKET[] memory) {
        // require(_maker != address(0), ' !_maker ;[-] ');
        address[] memory mark_hashes = CONFM.getMarketHashesForMakerOrCategory(_maker, _category); // note: checks for _category.length > 1 & _maker != address(0)
        require(mark_hashes.length > 0 && _retCnt > 0 && mark_hashes.length >= _idxStart + _retCnt, ' out of range :-p ');
        return _getMarketReturns(mark_hashes, _all, _live, _idxStart, _retCnt);
    }
    function _getMarketReturns(address[] memory _markHashes, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) private view returns(ICallitLib.MARKET[] memory) {
    // function _getMarketReturns(address[] memory _markHashes, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) private view returns(ICallitLib.MARKET_INFO[] memory) {
        // init return array
        ICallitLib.MARKET[] memory marks_ret = new ICallitLib.MARKET[](_retCnt); // pre-verified _retCnt > 0
        // ICallitLib.MARKET_INFO[] memory mark_infos = new ICallitLib.MARKET_INFO[](_retCnt);
        uint8 cnt_;
        for (uint8 i = 0; cnt_ < _retCnt && _idxStart + i < _markHashes.length;) {
            ICallitLib.MARKET memory mark = CONFM.getMarketForHash(_markHashes[_idxStart + i]);

            // check for mismatch, skip & inc only 'i' (note: _all = _live|!_live)
            if (!_all && mark.live != _live) { unchecked {i++;} continue; }
                 
            // log market found; continue w/ inc both 'i' & 'cnt_'
            marks_ret[cnt_] = mark; // note: use 'cnt_' not '_idxStart + i'
            // uint256[] memory dt_deadlines = new uint256[](3);
            // dt_deadlines[0] = mark.marketDatetimes.dtCallDeadline;
            // dt_deadlines[1] = mark.marketDatetimes.dtResultVoteStart;
            // dt_deadlines[2] = mark.marketDatetimes.dtResultVoteEnd;
            // mark_infos[cnt_] = ICallitLib.MARKET_INFO({
            //                     marketNum: mark.marketNum, 
            //                     marketName: mark.name, 
            //                     imgUrl: mark.imgUrl, 
            //                     initUsdAmntLP_tot: mark.marketUsdAmnts.usdAmntLP, 
            //                     resultLabels: mark.marketResults.resultLabels,
            //                     resultTickets: mark.marketResults.resultOptionTokens,
            //                     dtDeadlines: dt_deadlines,
            //                     live: mark.live
            //                 });
            unchecked {
                i++; cnt_++;
            }
        }
        // require(mark_infos.length > 0, ' none :-( ');
        // return mark_infos;
        require(marks_ret[0].maker != address(0), ' none :-( ');
        return marks_ret;
    }

    /* ref: https://docs.soliditylang.org/en/latest/contracts.html#fallback-function
        The fallback function is executed on a call to the contract if none of the other 
        functions match the given function signature, 
        or if no data was supplied at all and there is no receive Ether function. 
        The fallback function always receives data, but in order to also receive Ether it must be marked payable.
    */
    // invoked if function invoked doesn't exist OR no receive() implemented & ETH received w/o data
    fallback() external payable {
        // handle contract USD value deposits (convert PLS to USD stable)
        // fwd any PLS recieved to VAULT (convert to USD stable & process deposit)
        // VAULT.deposit{value: msg.value}(msg.sender);
        VAULT.deposit(msg.sender, address(0x0), msg.value);
        // NOTE: at this point, the vault has the deposited stable and the vault has stored accont balances
        //  emit DepositReceived(msg.sender, amntIn, 0);
    }
    function setAcctHandle(string calldata _handle) external {
        CONFM.setAcctHandle(msg.sender, _handle); // checks require for _handle
    }
    function setMarketInfo(address _anyTicket, string calldata _category, string calldata _rules, string calldata _imgUrl) external {
        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark,, address markHash) = CONFM._getMarketForTicket(_anyTicket); // reverts if market not found | address(0)
        require(mark.maker == msg.sender, ' only market maker :( ');
        require(mark.marketUsdAmnts.usdAmntPrizePool == 0, ' call deadline passed :( ');
        require(bytes(_category).length > 1, ' cat too short  :0 ');
        
        mark.category = _category;
        mark.rules = _rules;
        mark.imgUrl = _imgUrl;

        // log category created for this ticket's market hash
        CONFM.setHashMarket(markHash, mark, _category);
    }

    function makeNewMarket(string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                            address _altTokSpend, // pass 0x0 to use native PLS w/ curent acct balance
                            uint256 _altAmntLP,
                            // uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, 
                            string[] calldata _resultDescrs
                            ) external {
        // calc usd amnt needed for creating LPs (+ check if curr acct balance can cover it)
        //  note: if alt token == 0x0, then proceed w/o alt token deposit (attempt w/ curr acct balance)
        uint64 _usdAmntLP = LIB._uint64_from_uint256(CONF.RATIO_LP_USD_PER_TICK() * _resultLabels.length);
        uint64 curr_bal = CONFM.ACCT_USD_BALANCES(msg.sender);
        if (curr_bal < _usdAmntLP && _altTokSpend != address(0x0)) {
            // get alt tokens from sender EOA (fails/reverts if EOA doesn't do approval first)
            //  then perform swap from alt to stable & store in vault
            //  then get sender's usd balance & verify enough for min liquidity required
            IERC20(_altTokSpend).transferFrom(msg.sender, address(VAULT), _altAmntLP);
            VAULT.deposit(msg.sender, _altTokSpend, _altAmntLP);
            curr_bal = CONFM.ACCT_USD_BALANCES(msg.sender);
        }
        require(curr_bal >= _usdAmntLP, ' need more liquidity! :{=} ');

        // NOTE: the above check for curr acct balance covered 
        //  may mean that we can remove this check in DELEGATE.makeNewMarket

        // // _usdAmntLP = 0, triggers: set total LP = $1 * (# of result options), w/o needing to change ABI | function signature
        // //  note: _usdAmntLP acct balance check in DELEGATE.makeNewMarket
        // if (_usdAmntLP == 0) _usdAmntLP = LIB._uint64_from_uint256(CONF.RATIO_LP_USD_PER_TICK() * _resultLabels.length);
        // else require(_usdAmntLP >= CONF.MIN_USD_MARK_LIQ(), ' need more liquidity! :{=} ');
        require(2 <= _resultLabels.length && _resultLabels.length <= CONF.MAX_RESULTS() && _resultLabels.length == _resultDescrs.length, ' bad results count :( ');

        // initilize/validate market number for struct MARKET tracking
        uint256 mark_num = CONFM.getMarketCntForMaker(msg.sender);
        require(mark_num <= CONF.MAX_EOA_MARKETS(), ' > MAX_EOA_MARKETS :O ');

        // save this market and emit log (generates marketHash & stores in mark)
        // note: could possibly remove '_resultLabels' to save memory (ie. removed _resultDescrs succcessfully)
        ICallitLib.MARKET memory mark = DELEGATE.makeNewMarket(_name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, mark_num, msg.sender);
        mark.marketResults.resultDescrs = _resultDescrs; // bc it won't fit in 'DELEGATE.makeNewMark' :/

        // save new market in confM
        CONFM.storeNewMarket(mark, msg.sender); // sets HASH_MARKET

        emit MarketCreated(msg.sender, mark_num, mark.marketHash, _name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, mark.marketResults.resultOptionTokens, block.timestamp, true); // true = live

        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    }   
    // function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt) external { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
    function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt, address _altTokSpend, uint256 _altAmnt) external { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt                            
        require(_ticket != address(0), ' invalid _ticket :-{} ');

        // if sender provided 0 usd amnt, attempt alt token spend / deposit to account balance
        //  else, simply attempt to use curr account balance
        if (_usdAmnt == 0) { // use alt token
            require(_altTokSpend != address(0x0), ' alt tok required :/ ');

            // get alt tokens from sender EOA (fails/reverts if EOA doesn't do approval first)
            //  then perform swap from alt to stable & store in vault
            //  then set usd deposit amnt to usd amnt input var & get sender's new acct balance
            IERC20(_altTokSpend).transferFrom(msg.sender, address(VAULT), _altAmnt);
            _usdAmnt = VAULT.deposit(msg.sender, _altTokSpend, _altAmnt);
        }
        require(CONFM.ACCT_USD_BALANCES(msg.sender) >= _usdAmnt, ' low balance ;{ ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark, uint16 tickIdx,) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');
        require(mark.maker != msg.sender,' !promo buy for maker ;( '); 

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        (uint64 net_usdAmnt, uint256 tick_amnt_out) = DELEGATE.buyCallTicketWithPromoCode(mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _promoCodeHash, _usdAmnt, msg.sender);

        // check if msg.sender earned $CALL tokens
        uint64 callEarnedAmnt;
        if (_usdAmnt >= CONF.RATIO_PROMO_USD_PER_CALL_MINT()) {
            // mint $CALL to msg.sender & log $CALL votes earned
            callEarnedAmnt = _usdAmnt / CONF.RATIO_PROMO_USD_PER_CALL_MINT();
            _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned
        }

        // emit log
        emit PromoBuyPerformed(msg.sender, _promoCodeHash, mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out, callEarnedAmnt);
    }
    // function exeArbPriceParityForTicket(address _ticket) external { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
    function exeArbPriceParityForTicket(address _ticket, address _altTokSpend, uint256 _altAmnt) external { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
        require(_ticket != address(0), ' invalid _ticket :-{} ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark, uint16 tickIdx,) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');

        // calc target usd price for _ticket (in order to bring this market to price parity)
        //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        // (uint64 ticketTargetPriceUSD, uint64 tokensToMint, uint64 total_usd_cost, uint64 gross_stab_amnt_out, uint64 net_usd_profits) = VAULT.exeArbPriceParityForTicket(mark, tickIdx, MIN_USD_CALL_TICK_TARGET_PRICE, msg.sender);
        (uint64 ticketTargetPriceUSD, uint64 tokensToMint, uint64 total_usd_cost, uint64 gross_stab_amnt_out, uint64 net_usd_profits) = VAULT.exeArbPriceParityForTicket(mark, tickIdx, msg.sender);

        // total_usd_cost is the calc price to charge sender for minting tokensToMint
        //  HENCE, deduct this amount from their account balance
        //  note: algo to calc total_usd_cost = _ticketTargetPriceUSD * tokensToMint; (in VALUT._performTicketMint)
        //  note: algo to calc _ticketTargetPriceUSD found in LIB._getCallTicketUsdTargetPrice
        //  note: algo to calc tokensToMint found in LIB._calculateTokensToMint
        if (msg.sender != CONF.KEEPER()) { // free for KEEPER
            // NOTE: 102624, migrated from VAULT, lowers the file size compilation of VAULT (which is just about peaking)
            //  as well, it simplifies the callstack w/ "usd acct balance deduction" & "$CALL minting", executing in one place sequentially

            // if sender provided an alt token to use, then swap alt for stable to hold in thier VAULT account
            //  else, simply see if their VAULT account already has enough to cover
            if (_altTokSpend != address(0x0)) {
                // get how many alt tokens need to be swapped in, in order to get total_usd_cost amount of stable out
                address[] memory alt_stab_path = new address[](2);
                alt_stab_path[0] = _altTokSpend; // note: WPLS required for 'swapExactETHForTokens'
                alt_stab_path[1] = CONF.DEPOSIT_USD_STABLE();
                uint256 usdAmntOut = LIB._normalizeStableAmnt(VAULT._usd_decimals(), total_usd_cost, IERC20(alt_stab_path[1]).decimals());
                uint256 altAmntsIn = IUniswapV2Router02(CONF.DEPOSIT_ROUTER()).getAmountsIn(usdAmntOut, alt_stab_path)[0];
                if (altAmntsIn <= _altAmnt) { // use alt token
                    // get alt tokens from sender EOA (fails/reverts if EOA doesn't do approval first)
                    //  then perform swap from alt to stable & store in vault
                    IERC20(_altTokSpend).transferFrom(msg.sender, address(VAULT), _altAmnt);
                    VAULT.deposit(msg.sender, _altTokSpend, _altAmnt);
                }
            }

            // verify _arbExecuter usd balance covers contract sale of minted discounted tokens
            //  NOTE: _arbExecuter is buying 'tokensToMint' amount @ price = '_ticketTargetPriceUSD', from VAULT contract
            //      and then receiving the profits of VAULT selling minted tokens at <whatever> higher price (minus perc fees)
            require(CONFM.ACCT_USD_BALANCES(msg.sender) >= total_usd_cost, ' low balance :( ');

            // deduce that sale amount from their account balance
            CONFM.edit_ACCT_USD_BALANCES(msg.sender, total_usd_cost, false); // false = sub
        }

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = CONF.RATIO_CALL_MINT_PER_ARB_EXE();
        _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned

        // emit log of this arb price correction
        emit ArbPriceCorrectionExecuted(msg.sender, _ticket, ticketTargetPriceUSD, tokensToMint, gross_stab_amnt_out, total_usd_cost, net_usd_profits, callEarnedAmnt);
    }
    function closeMarketCallsForTicket(address _ticket) external { // NOTE: !_deductFeePerc; reward mint
        require(_ticket != address(0), ' invalid _ticket :-{} ');

        // algorithmic logic...
        //  get market for _ticket
        //  verify mark.marketDatetimes.dtCallDeadline has indeed passed
        //  loop through _ticket LP addresses and pull all liquidity

        // get MARKET & idx for _ticket & validate call time indeed ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark,, address markHash) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline <= block.timestamp && mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls not ready yet | closed :( ');
        // require(mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls closed already :p '); // usdAmntPrizePool: defaults to 0, unless closed and liq pulled to fill it

        // note: loops through market pair addresses and pulls liquidity for each
        mark.marketUsdAmnts.usdAmntPrizePool = DELEGATE.closeMarketCalls(mark); // NOTE: write to market
        CONFM.setHashMarket(markHash, mark, '');

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = CONF.RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS();
        _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned

        // emit log for this closed market calls event
        emit MarketCallsClosed(msg.sender, _ticket, mark.maker, mark.marketNum, markHash, mark.marketUsdAmnts.usdAmntPrizePool, callEarnedAmnt);
    }
    function castVoteForMarketTicket(address _senderTicketHash, address _markHash) external { // NOTE: !_deductFeePerc; reward mint
        require(_senderTicketHash != address(0) && _markHash != address(0), ' invalid hash :-{=} ');
        VOTER.castVoteForMarketTicket(msg.sender, _senderTicketHash, _markHash);

        // mint $CALL token reward to msg.sender
        _mintCallToksEarned(msg.sender, CONF.RATIO_CALL_MINT_PER_VOTE()); // emit CallTokensEarned
            // NOTE: -> DO NOT want to emit event log for casting votes
            //  this will allow people to see majority votes before voting

        // NOTE: -> DO NOT want to emit event log for casting votes 
        //  this will allow people to see majority votes before voting        
    }

    function closeMarketForTicket(address _ticket) external { // _deductFeePerc PERC_MARKET_CLOSE_FEE from mark.marketUsdAmnts.usdAmntPrizePool
        require(_ticket != address(0), ' invalid _ticket :-{-} ');
        // algorithmic logic...
        //  - count votes in mark.resultTokenVotes 
        //  - set mark.winningVoteResultIdx accordingly
        //  - calc market usdVoterRewardPool (using global KEEPER set percent)
        //  - calc market usdRewardPerVote (for voter reward claiming)
        //  - calc & mint $CALL to market maker (if earned)
        //  - set market 'live' status = false;

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark,, address markHash) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market voting not done yet ;=) ');

        // getting winning result index to set mark.winningVoteResultIdx
        //  for voter fee claim algorithm (ie. only pay majority voters)
        // mark.winningVoteResultIdx = _getWinningVoteIdxForMarket(mark); // NOTE: write to market
        // mark.winningVoteResultIdx = LIB._getWinningVoteIdxForMarket(mark.marketResults.resultTokenVotes); // NOTE: write to market
        uint64[] memory votes = VOTER.getResultVotesForMarketHash(markHash);
        mark.winningVoteResultIdx = LIB._getWinningVoteIdxForMarket(votes);

        // validate total % pulling from 'usdVoterRewardPool' is not > 100% (10000 = 100.00%)
        require(CONF.PERC_PRIZEPOOL_VOTERS() + CONF.PERC_MARKET_CLOSE_FEE() < 10000, ' perc error ;( ');

        // calc & save total voter usd reward pool (ie. a % of prize pool in mark)
        mark.marketUsdAmnts.usdVoterRewardPool = LIB._perc_of_uint64(CONF.PERC_PRIZEPOOL_VOTERS(), mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market

        // calc & set net prize pool after taking out voter reward pool (+ other market close fees)
        // mark.marketUsdAmnts.usdAmntPrizePool_net = mark.marketUsdAmnts.usdAmntPrizePool - mark.marketUsdAmnts.usdVoterRewardPool; // NOTE: write to market
        // mark.marketUsdAmnts.usdAmntPrizePool_net = LIB._deductFeePerc(mark.marketUsdAmnts.usdAmntPrizePool_net, CONF.PERC_MARKET_CLOSE_FEE(), mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market
        // uint64 usdAmntPrizePool_net_ = mark.marketUsdAmnts.usdAmntPrizePool - mark.marketUsdAmnts.usdVoterRewardPool;
        // mark.marketUsdAmnts.usdAmntPrizePool_net = LIB._deductFeePerc(usdAmntPrizePool_net_, CONF.PERC_MARKET_CLOSE_FEE(), mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market
        uint64 usdAmntPrizePool_net_ = mark.marketUsdAmnts.usdAmntPrizePool - mark.marketUsdAmnts.usdVoterRewardPool;
        uint64 usdMarkCloseFee = LIB._perc_of_uint64(CONF.PERC_MARKET_CLOSE_FEE(), mark.marketUsdAmnts.usdAmntPrizePool);
        LIB.debug_log_uint(msg.sender, 8, 16, 32, usdAmntPrizePool_net_, 256);
        LIB.debug_log_uint(msg.sender, 8, 16, 32, usdMarkCloseFee, 256);
        
        mark.marketUsdAmnts.usdAmntPrizePool_net = usdAmntPrizePool_net_ - usdMarkCloseFee; // NOTE: write to market
        LIB.debug_log_uint(msg.sender, 8, 16, 32, mark.marketUsdAmnts.usdAmntPrizePool_net, 256);
            // latest... 101124: still doesn't fucking work ^ w/ same enum error as below
            //  BUT... the LIB._perc_of_uint64 above it, works just fucking fine!!!
            //      and all inputs have confirmed to be exactly the same in the blockexplorer

            // LEFT OFF HERE .. latest failed here with enum error
            //  0x4e487b710000000000000000000000000000000000000000000000000000000000000012
            //  Panic errors use the selector 0x4e487b71 and the following codes:
            //  0x12 – Invalid enum value (i.e., an enum has been assigned an invalid value).
            
        // set private held VOTER. to public market's .resultTokenVotes for everyone to now see
        mark.marketResults.resultTokenVotes = votes; // NOTE: write to market
        
        // calc & save usd payout per vote ("usd per vote" = usd reward pool / total winning votes)
        mark.marketUsdAmnts.usdRewardPerVote = mark.marketUsdAmnts.usdVoterRewardPool / mark.marketResults.resultTokenVotes[mark.winningVoteResultIdx]; // NOTE: write to market

        // check if mark.maker earned $CALL tokens
        // if (mark.marketUsdAmnts.usdAmntLP >= CONF.RATIO_LP_USD_PER_CALL_TOK()) {
        if (mark.marketUsdAmnts.usdAmntPrizePool >= CONF.RATIO_LP_USD_PER_CALL_TOK()) {
            // mint $CALL to mark.maker & log $CALL votes earned
            // _mintCallToksEarned(mark.maker, mark.marketUsdAmnts.usdAmntLP / CONF.RATIO_LP_USD_PER_CALL_TOK()); // emit CallTokensEarned
            _mintCallToksEarned(mark.maker, mark.marketUsdAmnts.usdAmntPrizePool / CONF.RATIO_LP_USD_PER_CALL_TOK()); // emit CallTokensEarned
        }

        // close market
        mark.live = false; // NOTE: write to market
        CONFM.setHashMarket(markHash, mark, '');

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = CONF.RATIO_CALL_MINT_PER_MARK_CLOSE();
        _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned

        // un-lock ticket transfers (ie. call deadline passed & all liquidity pulled, no more bets)
        for (uint16 i=0; i < mark.marketResults.resultOptionTokens.length;) {
            ICallitTicket(mark.marketResults.resultOptionTokens[i]).setDeadlineTransferLock(false); // false = un-locked
            unchecked {i++;}
        }

        // emit log for closed market
        emit MarketClosed(msg.sender, _ticket, mark.maker, mark.marketNum, markHash, mark.winningVoteResultIdx, mark.marketUsdAmnts.usdAmntPrizePool_net, mark.marketUsdAmnts.usdVoterRewardPool, mark.marketUsdAmnts.usdRewardPerVote, callEarnedAmnt);
    }
    // LEFT OFF HERE ... what happens if the market result is 50/50
    //  .... i think it should simply execute normally for all tickets, not just the winning ticket
    function claimTicketRewards(address _ticket, bool _resultAgree) external { // _deductFeePerc PERC_WINNER_CLAIM_FEE from usdPrizePoolShare
        require(_ticket != address(0), ' invalid _ticket :-{+} ');
        require(IERC20(_ticket).balanceOf(msg.sender) > 0, ' ticket !owned ;( ');
        // algorithmic logic...
        //  - check if market voting ended & makr not live
        //  - check if _ticket is a winner
        //  - calc payout based on: _ticket.balanceOf(msg.sender) & mark.marketUsdAmnts.usdAmntPrizePool_net & _ticket.totalSupply();
        //  - send payout to msg.sender
        //  - burn IERC20(_ticket).balanceOf(msg.sender)
        //  - log _resultAgree in MARKET_REVIEW

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark, uint16 tickIdx, address markHash) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(!mark.live && mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market still live|voting ;) ');

        bool is_winner = mark.winningVoteResultIdx == tickIdx;
        if (is_winner) {
            // calc payout based on: _ticket.balanceOf(msg.sender) & mark.marketUsdAmnts.usdAmntPrizePool_net & _ticket.totalSupply();
            //  usdPerTicket = net prize / _ticket totalSupply brought down to 6 decimals
            //  NOTE: indeed normalizes to VAULT._usd_deciamls()
            // NOTE: not log logging | storing usdPerTicket
            // NOTE: not storing usdPrizePoolShare (but logged in 'transfer' emit)
            uint64 usdPerTicket = mark.marketUsdAmnts.usdAmntPrizePool_net / LIB._uint64_from_uint256(LIB._normalizeStableAmnt(ICallitTicket(_ticket).decimals(), IERC20(_ticket).totalSupply(), VAULT._usd_decimals()));
            uint64 usdPrizePoolShare = usdPerTicket * LIB._uint64_from_uint256(LIB._normalizeStableAmnt(ICallitTicket(_ticket).decimals(), IERC20(_ticket).balanceOf(msg.sender), VAULT._usd_decimals()));

            // send payout to msg.sender
            usdPrizePoolShare = LIB._deductFeePerc(usdPrizePoolShare, CONF.PERC_WINNER_CLAIM_FEE(), usdPrizePoolShare);
            VAULT._payUsdReward(msg.sender, usdPrizePoolShare, msg.sender); // emits 'transfer' event log
        } else {
            // NOTE: perc requirement limits ability for exploitation and excessive $CALL minting
            if (LIB._perc_total_supply_owned(_ticket, msg.sender) >= CONF.PERC_OF_LOSER_SUPPLY_EARN_CALL()) {
                // mint $CALL to loser msg.sender & log $CALL votes earned
                _mintCallToksEarned(msg.sender, CONF.RATIO_CALL_MINT_PER_LOSER()); // emit CallTokensEarned

                // NOTE: this action could open up a secondary OTC market for collecting loser tickets
                //  ie. collecting losers = minting $CALL
            } else {
                // if msg.sender doesn't have enough to claim as loser
                //  then revert (ie. do not burn, leave loser tokens on the market)
                revert(' need more losers :O ');
            }
        }

        // burn IERC20(_ticket).balanceOf(msg.sender)
        ICallitTicket cTicket = ICallitTicket(_ticket);
        cTicket.burnForRewardClaim(msg.sender);

        // log caller's review of market results
        ICallitLib.MARKET_REVIEW memory marketReview = LIB.genMarketResultReview(msg.sender, mark, CALL.getMarketReviewsForMaker(mark.maker), _resultAgree);
        CALL.pushAcctMarketReview(marketReview, mark.maker);

        // emit log event for reviewing market result
        emit MarketReviewed(msg.sender, _resultAgree, mark.maker, mark.marketNum, markHash, marketReview.agreeCnt, marketReview.disagreeCnt);
          
        // emit log event for claimed ticket
        emit TicketRewardsClaimed(msg.sender, _ticket, is_winner, _resultAgree);

        // NOTE: no $CALL tokens minted for this action
    }
    function claimVoterRewards() external { // _deductFeePerc PERC_VOTER_CLAIM_FEE from usdRewardOwed
        DELEGATE.claimVoterRewards(); // emits 'VoterRewardsClaimed'
        // NOTE: no $CALL tokens minted for this action
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (CALLIT MANAGER) // NOTE: migrate to CallitVault (ALL)
    /* -------------------------------------------------------- */
    function _mintCallToksEarned(address _receiver, uint64 _callAmnt) private {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        //  NOTE: _callAmnt decimals should be accounted for on factory invoking side
        //      allows for factory minting fractions of a token if needed
        CALL.mintCallToksEarned(_receiver, _callAmnt * 10**uint8(CALL.decimals()), _callAmnt, msg.sender); 
            // NOTE: updates CALL.EARNED_CALL_VOTES & emits CallTokensEarned
    }
}
