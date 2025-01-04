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

// inherited contracts (remix)
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ICallConfig.sol";

interface ICallitToken {
    // function ACCT_CALL_VOTE_LOCK_TIME(address _key) external view returns(uint256); // public
    // function EARNED_CALL_VOTES(address _key) external view returns(uint64); // public
    function mintCallToksEarned(address _receiver, uint256 _callAmntMint, uint64 _callVotesEarned, address _sender) external;
    // function decimals() external pure returns (uint8);
    // function pushAcctMarketReview(ICallitLib.MARKET_REVIEW memory _marketReview, address _maker) external;
    // function getMarketReviewsForMaker(address _maker) external view returns(ICallitLib.MARKET_REVIEW[] memory);
}

contract MemeCall {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    /* GLOBALS (CALLIT) */
    string public tVERSION = '0.74';
    bool private FIRST_ = true;
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallConfig private CONF;
    ICallMarket private MARKET; // set via CONF_setConfig
    ICallVoter private VOTER; // set via CONF_setConfig
    ICallLib private LIB;     // set via CONF_setConfig
    // ICallitVault private VAULT; // set via CONF_setConfig
    // ICallitDelegate private DELEGATE; // set via CONF_setConfig
    // ICallitToken private CALL;  // set via CONF_setConfig
    uint64 private CALL_INIT_MINT;

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    event MarketCreated(address _maker, uint256 _markNum, address _markHash, string _topic, string _category, uint64 _usdEntryFee, uint256 _dtSubmitDeadline, uint256 _secVoteTime, uint256 _blockTime, bool _live);

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
        CONF = ICallConfig(ADDR_CONFIG);
        MARKET = ICallMarket(CONF.ADDR_MARKET());
        VOTER = ICallVoter(CONF.ADDR_VOTER());
        LIB = ICallLib(CONF.ADDR_LIB());
        VAULT = ICallVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
        // DELEGATE = ICallitDelegate(CONF.ADDR_DELEGATE());
        // CALL = ICallitToken(CONF.ADDR_CALL());
    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // EOAs DO NOT retain ‘voter status’ if ...
    //  1) they do not currently own that 'certain amount’ of voter tokens 
    //  2) they have not won a competition in the past
    modifier onlyVoter() {
        // TODO: integrate check for voter
        _;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - UI accessors
    /* -------------------------------------------------------- */
    // VOTER support
    function getMyVoterHash() external view returns(address) {
        // *WARNING* user must have their wallet conencted to use this function
        //  ie. read request must come from user's EOA and not the RPC server default assigned for 'view' requests
        return VOTER.getVoterHash(msg.sender); // executes require checks
    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // The public may freely view a list of open competitions on the dapp
    // - “Meme Creators” choose one to participate in & submit a url link to their meme
    // - the url may be from any social media or HTTP server in the world, etc.
    // - they must also pay the entry free along with their submission
    // - can pay in any ERC20 token (amnt value must = the USD entry fee amnt)
    function getMemeCallsOpen() external returns() {
        
    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // “Voters” use the dapp to view all meme submissions for all ‘pending’ competitions 
    // - pending = submission time passed + voting time started
    // - note: only voters are aloud to do this (not ‘meme creators’ or the public)
    // When any competition submission time has lapsed ... 
    // - “Voters” may then choose to vote for a winner
    function getMemeCallsPending() external onlyVoter returns() {

    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // After voting is complete for any given competition (ie. the competition is now ‘closed’) 
    // - the full competition becomes available for the public to see
    //      (including both winning & losing memes)
    function getMemeCallsClosed() external returns() {

    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // passive rewards (for winners)
    // - any EOA that actively possess a minted NFT,
    //      will earn a small % of each competition prize pool 
    // - note: winning a competition is NOT required for this
    //      (ie. provides real world value & incentive for holding & trading our NFTs)
    // active rewards (for winning + voting)
    // - winners get minted 'some amount’ of voter token for each competition won 
    // - winners earn a large % of price pool won
    // - winners get their meme minted into an NFT
    // - voters get minted 'some amount’ of voter token for each competition vote 
    // - voters earn a small % of each prize pool they voted in
    //      note: the ‘competition maker’ earns an extra small % of that prize pool
    function getMyRewardsOwed() external returns() {

    }

    /* -------------------------------------------------------- */
    /* PUBLIC - UI mutators
    /* -------------------------------------------------------- */
    // VOTER support
    function genMyVoterHash() external {
        VOTER.genVoterHash(msg.sender); // executes require checks
    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // Any “Voter” may create a competition
    // - they choose any topic (ie. “best meme to support $BEAR on PulseChain”)
    // - they set a USD amount entry fee (ie. $10.00)
    // - they set a submission time frame + voting time aloud (ie. 1 week to submit memes + 24hrs for voting)
    function createNewMemeCall(string calldata _topic, 
                                string calldata _category,
                                string calldata _rules,
                                string calldata _imgUrl,
                                uint64 _usdEntryFee, // 6 decimal precision (eg. 1000000 = $1.00)
                                uint256 _dtSubmitDeadline, 
                                uint256 _secVoteTime) external {
        // validate input params
        require(block.timestamp < _dtSubmitDeadline && _secVoteTime >= CONF.SEC_DEFAULT_VOTE_TIME(), ' invalid dt|vt settings :[] ');

        // check for admin defualt vote time, update _dtResultVoteEnd accordingly
        if (CONF.USE_SEC_DEFAULT_VOTE_TIME()) _secVoteTime = _dtSubmitDeadline + CONF.SEC_DEFAULT_VOTE_TIME();

        // initilize/validate market number for struct MARKET tracking
        uint256 mark_num = MARKET.getMarketCntForMaker(msg.sender);
        require(mark_num <= CONF.MAX_EOA_MARKETS(), ' > MAX_EOA_MARKETS :O ');

        // save this market and emit log (generates new market hash)
        ICallLib.MARKET memory mark = ICallLib.MARKET({maker:_sender, 
                                                marketNum:mark_num, 
                                                marketHash:LIB.generateAddressHash(msg.sender, string(abi.encodePacked(mark_num))),
                                                topic:_topic,

                                                // marketInfo:MARKET_INFO("", "", ""),
                                                category:_category,
                                                rules:_rules, 
                                                imgUrl:_imgUrl, 
                                                marketUsdAmnts:ICallitLib.MARKET_USD_AMNTS(_usdEntryFee, 0, 0, 0, 0, 0, 0), 
                                                // marketDatetimes:ICallitLib.MARKET_DATETIMES(_dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd), 
                                                dtSubmitDeadline:_dtSubmitDeadline,
                                                secVoteTime:_secVoteTime,
                                                // marketResults:VAULT.createDexLP(_sender, _mark_num, _resultLabels, net_usdAmntLP, CONF.RATIO_LP_TOK_PER_USD()), 
                                                marketSubmits:ICallLib.MARKET_SUBMITS(new address[](0), new string[](0), new address[](0));
                                                winningVoteResultIdx:0, 
                                                blockTimestamp:block.timestamp, 
                                                blockNumber:block.number, 
                                                status:0, // status: 0=open (submit started), 1=pending (submit time passed + vote started), 2=closed (vote time passed)
                                                live:true} // true = !closed | status < 2
                                                ); 

        // save new market in MARKET (also logs market hash)
        MARKET.storeNewMarket(mark, msg.sender); // sets HASH_MARKET

        // log category created for this market hash (resets HASH_MARKET)
        CONFM.setHashMarket(mark.marketHash, mark, _category);
            // LEFT OFF HERE ... need exernal function for maker to update category if needed (limit 1 time)

        emit MarketCreated(msg.sender, mark_num, mark.marketHash, _topic, _category, _usdEntryFee, _dtSubmitDeadline, _secVoteTime, block.timestamp, true); // true = live

        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'

    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // The public may freely view a list of open competitions on the dapp
    // - “Meme Creators” choose one to participate in & submit a url link to their meme
    // - the url may be from any social media or HTTP server in the world, etc.
    // - they must also pay the entry free along with their submission
    //      - can pay in any ERC20 token (amnt value must = the USD entry fee amnt)
    function submitMemeCallEntry(address _marketHash, string calldata _memeUrl, address _memeHash, address _altTokSpend, uint256 _altAmnt) external {
        require(_marketHash != address(0) && bytes(_memeUrl).length > 0, ' invalid args :( ');

        // get market for this hash (verify submit deadline not passed)
        ICallLib.MARKET memory mark = MARKET.getMarketForHash(_marketHash);
        require(mark.dtSubmitDeadline >= block.timestamp, ' submit deadline passed :/ ');

        // ref: legacy CallitFactory.sol -> buyCallTicketWithPromoCode
        // if sender provided any _altAmnt, attempt alt token spend / deposit to account balance
        //  else, simply attempt to use curr account balance
        uint64 usdDepositVal;
        if (_altAmnt > 0) { // use alt token for deposit, else just check acct balance
            require(_altTokSpend != address(0x0), ' alt tok required :/ ');

            // validate EOA prior alt approval from client side
            require(IERC20(_altTokSpend).allowance(msg.sender, address(this)) >= _altAmnt, ' need alt approval');

            // get alt tokens from sender EOA (fails/reverts if EOA doesn't do approval first)
            IERC20(_altTokSpend).transferFrom(msg.sender, address(VAULT), _altAmnt);

            // swap from alt to stable & store in vault (updates sender's MARKET acct balance)
            //  note: tracking entry fees & claiming USD rewards, handled via CallMarket.ACCT_USD_BALANCES
            usdDepositVal = VAULT.deposit(msg.sender, _altTokSpend, _altAmnt);
        }

        // verify account usd balance can cover entry fee
        require(MARKET.ACCT_USD_BALANCES(msg.sender) >= mark.marketUsdAmnts.usdEntryFee, ' low balance ;{ ');

        // append msg.sender & meme url & meme hash to MARKET struct (mark.marketSubmits)
        //  ie. tracks entry fee paid by msg.sender for this _marketHash
        mark.marketUsdAmnts.usdAmntPrizePool = DELEGATE.closeMarketCalls(mark); // NOTE: write to market
        mark.marketSubmits.entryFeePaidEOAs = ICallLib.addAddressToArraySafe(msg.sender, mark.marketSubmits.entryFeePaidEOAs, true); // true = no dups
        mark.marketSubmits.memeUrls = ICallLib.addStringToArraySafe(_memeUrl, mark.marketSubmits.memeUrls, true); // true = no dups
        mark.marketSubmits.memeHashes = ICallLib.addAddressToArraySafe(_memeHash, mark.marketSubmits.memeHashes, true); // true = no dups

        // reset HASH_MARKET with this mark changes
        MARKET.setHashMarket(markHash, mark, ''); // '' = DO NOT add markHash to array for category in "mapping(string => address[]) CATEGORY_MARK_HASHES"

        // debit usdEntryFee from msg.sender account & credit to _marketHash account
        //  note: USD rewards claimed (via voter/winner/passive EOAs): taken directly from ACCT_USD_BALANCES(_marketHash)
        MARKET.edit_ACCT_USD_BALANCES(msg.sender, mark.usdEntryFee, false); // false = sub
        MARKET.edit_ACCT_USD_BALANCES(_marketHash, mark.usdEntryFee, true); // true = add

        // TODO: validate VAULT balance still covers collective ACCT_USD_BALANCES owed (maybe)

        // TODO: emit log event
    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // When any competition submission time has lapsed ... 
    // - “Voters” may then choose to vote for a winner
    // *NOTE*: 2 Requirements for EOAs to retain ‘voter status’ ...
    //  1) EOA must have won a previous competition in the past 
    //      - note: this is a ‘non-transferable’ value set (mitigates whales from acquiring tokens and controlling votes)
    //      - each EOA winner gets exactly 1 vote
    //  2) EOA winner must currently hold a ‘certain min amount’ of voter tokens
    //      - may be freely purchased from open market
    //      - EOA voter payout ($) is bound to voter token holdings (ie. payout = prize pool % / token)
    //      - EOA voter weight (#) is bound to voter token holdings (ie. weight = 1vote / token)
    //          OR 
    //      - each EOA winner gets exactly 1 vote (regardless of voter token holdings)
    //         NOTE: opens risk of milicious actors to acquire winning EOAs (ie. to increase voting weight)
    //              HOWEVER, voting weight DOES NOT matter since payout is bound to token holdings
    //                  HENCE, there's no benefit from acquiring winning addies & controlling comp results
    //
    // *NOTE*: should have the ability to track/view voters for market makers (ie. public mapping of some sort)
    //          this is so the public can see/detect if a market maker is constantly voting for themselves
    //           (ie. controlling the votes/winners in their market history and decide not to pay entry fee)
    //
    // *NOTE*: PROBLEM: how do you ensure people don't cheat and steal the pools by controlling votes?
    //          1) need to ensure users can't gather voting power by gathering tokens
    //          2) need to ensure meme creators can get info from the contract to detect cheaters before entering
    //
    // 122324: LEFT OFF HERE ... algo options to ensure user CANNOT exploit the ability to earn voter tokens
    //  ALGORITHM_1: LEFT OFF HERE ... need some ways to discourage creating fake markets and votes
    //                  1) make the contract service fee >= # of entries * current $CALL/USD market price
    //                      - this makes $CALL voter token minting more expensive than buying from dexes
    //                  2) track 'voter status': vote count & win count requirements (ALGORITHM_2 below)
    //                      - ratio vote count of $CALL voter tokens held? (ie. 1vote:1token; ratio set by keeper; no self-voting)
    //                          - creates most demand for $CALL to be held off the market
    //                          - creates most risk for whales to acquire $CALL and manipulate voting
    //                              mitigate risk: make $CALL voter token minting more expensive than buying from dexes
    //                          - voting EOAs can retain more voting weight than others (relative to market)
    //                          - voting EOAs can earn larger % of prize pool than others    
    //  ALGORITHM_2: retained 'voter status': vote count & win count requirements
    //      NOTE: this algo doesn't fully solve the problem in algo_1 above
    //      How many votes does a retained 'voter status' EOA get ...
    //          - ratio vote count of $CALL voter tokens held per comp win count? (ie. 1vote:1token / win; ratio set by keeper; no self-voting)
    //              - creates limited demand for $CALL to be held off the market (incentive to hold is bound to win count)
    //              - creates limited risk for whales to acquire $CALL and manipulate voting (must also acquire wins)
    //              - voting EOAs can retain more voting weight than others (relative to market)
    //              - voting EOAs can earn larger % of prize pool than others
    //          - ratio vote count of $CALL voter tokens held? (ie. 1vote:1token; ratio set by keeper; no self-voting)
    //              - creates most demand for $CALL to be held off the market
    //              - creates most risk for whales to acquire $CALL and manipulate voting
    //              - voting EOAs can retain more voting weight than others (relative to market)
    //              - voting EOAs can earn larger % of prize pool than others
    //          - one vote count per competition win count? (ie. 1vote:1win; no self-voting)
    //              - creates limited demand for $CALL to be held off the market (only relative to win count)
    //              - creates most risk for whales to acquire wins and manipulate voting (even w/ no self-voting)
    //              - voting EOAs can retain more voting weight than others
    //              - voting EOAs can earn larger % of prize pool than others
    //          - one vote count per comptition winner? (ie. 1vote:1winner; no self-voting)
    //              - creates minimal demand for $CALL to be held off the market (only enough to vote once)
    //              - creates limited risk for whales to acquire wins and manipulate voting (even w/ no self-voting)
    //              - voting EOAs all have the same voting weight
    //              - voting EOAs all earn same % of prize pool
    function castVoteForMemeCall(address _memeHash, address _marketHash) external {
        // require(_memeHash != address(0) && _marketHash != address(0), ' invalid input :{} ');
        // validates input params & ACCT_VOTER_HASH[msg.sender] exists
        ICallLib.MARKET memory mark = VOTER.castVoteForMarketMeme(msg.sender, _memeHash, _markHash);

        // reset HASH_MARKET with this mark changes
        MARKET.setHashMarket(_marketHash, mark, ''); // '' = DO NOT add markHash to array for category in "mapping(string => address[]) CATEGORY_MARK_HASHES"
    }
    // function castVoteForMemeCall(address _senderMemeHash, address _marketHash) external {
    //     require(_senderMemeHash != address(0) && _marketHash != address(0), ' invalid input :{} ');
    //     VOTER.castVoteForMarketMeme(msg.sender, _senderTicketHash, _markHash); // validates ACCT_VOTER_HASH[msg.sender] exists
    // }

    // ref: SDD_meme-comp_112524_1855.pdf
    // After voting is complete for any given competition (ie. the competition is now ‘closed’) 
    // - “Voters” then use the dapp to claim their rewards for voting
    //      rewards: small percent of prize pool + minted voter tokens 
    function claimRewardVoter() external onlyVoter {
        // ref: SDD_meme-comp_112524_1855.pdf
        // - voters get minted 'some amount’ of voter token for each competition vote 
        // - voters earn a small % of each prize pool they voted in
        //      note: the ‘competition maker’ earns an extra small % of that prize pool

        // _mintCallToksEarned(address _receiver, uint64 _callAmnt);
    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // After voting is complete for any given competition (ie. the competition is now ‘closed’) 
    // -“Winning creators” then use the dapp to claim their rewards for winning
    //      rewards: large percent of prize pool + minted voter tokens + meme minted into an NFT
    function claimRewardWinner() external {
        // ref: SDD_meme-comp_112524_1855.pdf
        // active rewards (for winning + voting)
        // - winners get minted 'some amount’ of voter token for each competition won 
        // - winners earn a large % of price pool won
        // - winners get their meme minted into an NFT

        // _mintCallToksEarned(address _receiver, uint64 _callAmnt);
    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // passive rewards (for winners)
    // - any EOA that actively possess a minted NFT,
    //      will earn a small % of each competition prize pool 
    // - note: winning a competition is NOT required for this
    //      (ie. provides real world value & incentive for holding & trading our NFTs)
    function claimRewardPassive() external {
        // LEFT OFF HERE ... should passive rewards be transferrable along with their NFT?
        //      (should the contract track passive rewards by NFT or by EOA holding the NFT?)
        //  ie. should EOAs be able to claim rewards owed to them AFTER they have transferred their NFT to someone else?
        //      or should the rewards be transferrable along with the NFT?
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - supporting
    /* -------------------------------------------------------- */
    function _mintCallToksEarned(address _receiver, uint64 _callAmnt) private {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        //  NOTE: _callAmnt decimals should be accounted for on factory invoking side
        //      allows for factory minting fractions of a token if needed
        CALL.mintCallToksEarned(_receiver, _callAmnt * 10**uint8(CALL.decimals()), _callAmnt, msg.sender); 
            // NOTE: updates CALL.EARNED_CALL_VOTES & emits CallTokensEarned
    }

}