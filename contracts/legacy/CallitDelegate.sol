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
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; // deploy
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// import "./CallitTicket.sol";
import "./ICallitLib.sol";
import "./ICallitVault.sol";
import "./ICallitConfig.sol";

interface IERC20x {
    function decimals() external pure returns (uint8);
}
interface ICallitTicket {
    // function burnForRewardClaim(address _account) external;
    // function decimals() external pure returns (uint8);
    function setDeadlineTransferLock(bool _lock) external;
}

contract CallitDelegate {
    /* GLOBALS (CALLIT) */
    // bool private ONCE_ = true;
    bool private FIRST_ = true;
    string public constant tVERSION = '0.51';   
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    ICallitMarket private CONFM; // set via CONF_setConfig
    ICallitVoter private VOTER; // set via CONF_setConfig
    ICallitLib private LIB;     // set via CONF_setConfig
    ICallitVault private VAULT; // set via CONF_setConfig

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // legacy & callit promo
    event KeeperTransfer(address _prev, address _new);
    event PromoCreated(address _promoHash, address _promotor, string _promoCode, uint64 _usdTarget, uint64 usdUsed, uint16 _percReward, address _creator, uint256 _blockNumber);
    event PromoRewardsPaid(address _sender, address _promoCodeHash, uint64 _usdPaid, address _promotor);
    event VoterRewardsClaimed(address _claimer, uint64 _usdRewardOwed, uint64 _usdRewardOwed_net);

    /* -------------------------------------------------------- */
    /* CONSTRUTOR
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
    modifier onlyAdmin() {
        require(msg.sender == CONF.KEEPER() || CONF.ADMINS(msg.sender) == true, " !admin :p");
        // require(msg.sender == CONF.KEEPER() || CONF.adminStatus(msg.sender) == true, " !admin :p");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.KEEPER(), " !keeper & !fact :p");
        _;
    }
    modifier onlyConfig() { 
        // allows 1st onlyConfig attempt to freely pass
        //  NOTE: don't waste this on anything but CONF_setConfig
        if (!FIRST_) 
            require(msg.sender == address(CONF), ' !CONF :[ ');
        FIRST_ = false;
        _;
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :<> ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(_conf);
        CONFM = ICallitMarket(CONF.ADDR_CONFM());
        VOTER = ICallitVoter(CONF.ADDR_VOTER());
        LIB = ICallitLib(CONF.ADDR_LIB());
        VAULT = ICallitVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
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
    /* PUBLIC - ADMIN SUPPORT
    /* -------------------------------------------------------- */
    // CALLIT admin
    function ADMIN_initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint16 _percReward) external onlyAdmin {
        // address promoCodeHash = _initPromoForWallet(_promotor, _promoCode, _usdTarget, _percReward, msg.sender);

        // no 2 percs taken out of promo buy
        require(CONF.PERC_PROMO_BUY_FEE() + _percReward < 10000, ' invalid promo buy _perc :(=) ');
        require(_promotor != address(0) && LIB._validNonWhiteSpaceString(_promoCode) && _usdTarget >= CONF.MIN_USD_PROMO_TARGET(), ' !param(s) :={ ');
        address promoCodeHash = LIB._generateAddressHash(_promotor, _promoCode);
        ICallitLib.PROMO memory promo = CONFM.getPromoForHash(promoCodeHash);
        require(promo.promotor == address(0), ' promo already exists :-O ');
        CONFM.setPromoForHash(promoCodeHash, ICallitLib.PROMO(_promotor, _promoCode, promoCodeHash, _usdTarget, 0, _percReward, msg.sender, block.number));
        emit PromoCreated(promoCodeHash, _promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
    }
    function checkPromoBalance(address _promoCodeHash) external view returns(uint64) {
        // return _checkPromoBalance(_promoCodeHash);
        ICallitLib.PROMO memory promo = CONFM.getPromoForHash(_promoCodeHash);
        // require(promo.promotor != address(0), ' invalid promo :-O ');
        return promo.usdTarget - promo.usdUsed; // note: w/o 'require', should simply return 0
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - FACTORY SUPPORT
    /* -------------------------------------------------------- */
    // invoked if function invoked doesn't exist OR no receive() implemented & ETH received w/o data
    fallback() external payable {
        // fwd any PLS recieved to VAULT (convert to USD stable & process deposit)
        VAULT.deposit{value: msg.value}(msg.sender);
    }
    function makeNewMarket( string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                            uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, // note: could possibly remove to save memory (ie. removed _resultDescrs succcessfully)
                            uint256 _mark_num,
                            address _sender
                            ) external onlyFactory returns(ICallitLib.MARKET memory) { 
        require(CONFM.ACCT_USD_BALANCES(_sender) >= _usdAmntLP, ' low balance ;{ ');
        require(block.timestamp < _dtCallDeadline && _dtCallDeadline < _dtResultVoteStart && _dtResultVoteStart < _dtResultVoteEnd, ' invalid dt settings :[] ');

        // check for admin defualt vote time, update _dtResultVoteEnd accordingly
        if (CONF.USE_SEC_DEFAULT_VOTE_TIME()) _dtResultVoteEnd = _dtResultVoteStart + CONF.SEC_DEFAULT_VOTE_TIME();

        // deduct 'market maker fees' from _usdAmntLP
        uint64 net_usdAmntLP = LIB._deductFeePerc(_usdAmntLP, CONF.PERC_MARKET_MAKER_FEE(), _usdAmntLP);

        // gen market hash references & store w/ new market in delegate
        address markHash = LIB._generateAddressHash(_sender, string(abi.encodePacked(_mark_num)));

        // save this market and emit log
        ICallitLib.MARKET memory mark = ICallitLib.MARKET({maker:_sender, 
                                                marketNum:_mark_num, 
                                                marketHash:markHash,
                                                name:_name,

                                                // marketInfo:MARKET_INFO("", "", ""),
                                                category:"",
                                                rules:"", 
                                                imgUrl:"", 

                                                marketUsdAmnts:ICallitLib.MARKET_USD_AMNTS(_usdAmntLP, 0, 0, 0, 0), 
                                                marketDatetimes:ICallitLib.MARKET_DATETIMES(_dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd), 
                                                // marketResults:mark_results,
                                                marketResults:VAULT.createDexLP(_sender, _mark_num, _resultLabels, net_usdAmntLP, CONF.RATIO_LP_TOK_PER_USD()), 
                                                winningVoteResultIdx:0, 
                                                blockTimestamp:block.timestamp, 
                                                blockNumber:block.number, 
                                                live:true}); // true = live

        // Loop through resultOptionTokens and log deployed ERC20s tickets into TICKET_MAKER mapping
        CONFM.setMakerForTickets(_sender, mark.marketResults.resultOptionTokens);

        // deduct full OG usd input from account balance
        CONFM.edit_ACCT_USD_BALANCES(_sender, _usdAmntLP, false); // false = sub

        // return (mark,_dtResultVoteEnd);
        return mark;
        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    }
    function buyCallTicketWithPromoCode(address _usdStableResult, address _ticket, address _promoCodeHash, uint64 _usdAmnt, address _sender) external onlyFactory returns(uint64, uint256) { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
        ICallitLib.PROMO memory promo = CONFM.getPromoForHash(_promoCodeHash);
        require(promo.promotor != address(0) && promo.promotor != _sender && promo.usdTarget - promo.usdUsed >= _usdAmnt && promo.promotor != _sender, ' invalid promo :-O ');

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        // NOTE: potential exploitation preventions (in current callstack 'require' checks)
        //  promotor can't earn both $CALL & USD reward w/ their own promo
        //  maker can't earn $CALL twice on same market (from both "promo buy" & "making market")

        // update promo.usdUsed (add full OG input _usdAmnt)
        promo.usdUsed += _usdAmnt;

        // pay promotor usd reward & purchase _sender's tickets from DEX
        //  NOTE: indeed verifies "_percReward + PERC_PROMO_BUY_FEE < 10000"
        // NOTE: *WARNING* if this require fails ... 
        //  then this promo code cannot be used until PERC_PROMO_BUY_FEE is lowered accordingly
        return VAULT._payPromotorDeductFeesBuyTicket(promo.percReward, _usdAmnt, promo.promotor, _promoCodeHash, _ticket, _usdStableResult, _sender);
    }
    function closeMarketCalls(ICallitLib.MARKET memory mark) external onlyFactory returns(uint64) { // NOTE: !_deductFeePerc; reward mint
        // algorithmic logic...
        //  get market for _ticket
        //  verify mark.marketDatetimes.dtCallDeadline has indeed passed
        //  loop through _ticket LP addresses and pull all liquidity

        // loop through pair addresses and pull liquidity 
        address[] memory ticketLPs = mark.marketResults.resultTokenLPs;
        uint64 usdAmntPrizePool = 0;
        for (uint16 i = 0; i < ticketLPs.length;) { // MAX_RESULTS is uint16
            // NOTE: amountToken1 = usd stable amount received (which is all we care about)
            uint256 amountToken1 = VAULT._exePullLiquidityFromLP(mark.marketResults.resultTokenRouters[i], ticketLPs[i], mark.marketResults.resultOptionTokens[i], mark.marketResults.resultTokenUsdStables[i]);

            // update market prize pool usd received from LP (usdAmntPrizePool: defualts to 0)
            usdAmntPrizePool += LIB._uint64_from_uint256(LIB._normalizeStableAmnt(IERC20x(mark.marketResults.resultTokenUsdStables[i]).decimals(), amountToken1, VAULT._usd_decimals())); 

            // local ticket transfers (ie. call deadline passed & all liquidity pulled, no more bets)
            ICallitTicket(mark.marketResults.resultOptionTokens[i]).setDeadlineTransferLock(true); // true = locked

            unchecked {
                i++;
            }
        }

        return usdAmntPrizePool;
    }
    function claimVoterRewards(address _sender) external onlyFactory { // _deductFeePerc PERC_VOTER_CLAIM_FEE from usdRewardOwed
        // NOTE: loops through all non-piad msg.sender votes (including 'live' markets)
        // require(ACCT_MARKET_VOTES[_sender].length > 0, ' no un-paid market votes :) ');
        ICallitLib.MARKET_VOTE[] memory sender_votes = VOTER.getMarketVotesForAcct(_sender, false); // false = un-paid
        require(sender_votes.length > 0, ' no un-paid market votes :) ');
        uint64 usdRewardOwed = 0;
        for (uint64 i = 0; i < sender_votes.length;) { // uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
            ICallitLib.MARKET_VOTE memory m_vote = sender_votes[i];
            (ICallitLib.MARKET memory mark,,) = CONFM._getMarketForTicket(m_vote.voteResultToken); // reverts if market not found | address(0)

            // skip live MARKETs
            if (mark.live) {
                unchecked {i++;}
                continue;
            }

            // verify voter should indeed be paid & add usd reward to usdRewardOwed
            //  ie. msg.sender's vote == winning result option (majority of votes)
            //       AND ... this MARKET_VOTE has not been paid yet
            if (m_vote.voteResultIdx == mark.winningVoteResultIdx && !m_vote.paid) {
                usdRewardOwed += mark.marketUsdAmnts.usdRewardPerVote * m_vote.voteResultCnt;
                m_vote.paid = true; // set paid // NOTE: write to market vote
            }

            // check for 'paid' MARKET_VOTE found in ACCT_MARKET_VOTES (& move to ACCT_MARKET_VOTES_PAID)
            //  NOTE: integration moves MARKET_VOTE that was just set as 'paid' above, to ACCT_MARKET_VOTES_PAID
            //   AND ... catches any 'prev-paid' MARKET_VOTEs lingering in non-paid ACCT_MARKET_VOTES array
            if (m_vote.paid) { // NOTE: move this market vote index 'i', to paid
                // add this MARKET_VOTE to ACCT_MARKET_VOTES_PAID[msg.sender]
                // remove _idxMove MARKET_VOTE from ACCT_MARKET_VOTES[msg.sender]
                //  by replacing it with the last element (then popping last element)
                VOTER.moveMarketVoteToPaid(_sender, i, m_vote); // does not write to market
                // ACCT_MARKET_VOTES_PAID[_sender].push(m_vote);
                // uint64 lastIdx = uint64(ACCT_MARKET_VOTES[_sender].length) - 1;
                // if (i != lastIdx) { ACCT_MARKET_VOTES[_sender][i] = ACCT_MARKET_VOTES[_sender][lastIdx]; }
                // ACCT_MARKET_VOTES[_sender].pop(); // Remove the last element (now a duplicate)

                continue; // Skip 'i++'; continue w/ current idx, to check new item at position 'i'
            }
            unchecked {i++;}
        }

        // deduct fees and pay voter rewards
        // pay w/ lowest value whitelist stable held (returns on 0 reward)
        uint64 usdRewardOwed_net = LIB._deductFeePerc(usdRewardOwed, CONF.PERC_VOTER_CLAIM_FEE(), usdRewardOwed);
        VAULT._payUsdReward(_sender, usdRewardOwed_net, _sender);
        
        // emit log for rewards claimed
        emit VoterRewardsClaimed(msg.sender, usdRewardOwed, usdRewardOwed_net);

        // NOTE: no $CALL tokens minted for this action   
    }
    function claimPromotorRewards(address _promoCodeHash) external {
        ICallitLib.PROMO memory promo = CONFM.getPromoForHash(_promoCodeHash);
        require(promo.promotor != address(0), ' !promotor :p ');

        uint64 usdTargRem = promo.usdTarget - promo.usdUsed;
        require(usdTargRem < LIB._perc_of_uint64(CONF.PERC_REQ_CLAIM_PROMO_REWARD(), promo.usdTarget), ' target not hit yet :0 ');
        uint64 usdPaid = VAULT.payPromoUsdReward(msg.sender, _promoCodeHash, promo.usdUsed, promo.promotor); // invokes _payUsdReward
        emit PromoRewardsPaid(msg.sender, _promoCodeHash, usdPaid, promo.promotor);
    }
}