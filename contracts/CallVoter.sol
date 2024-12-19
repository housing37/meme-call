// SPDX-License-Identifier: UNLICENSED
// ref: https://ethereum.org/en/history
//  code size limit = 24576 bytes (a limit introduced in Spurious Dragon _ 2016)
//  code size limit = 49152 bytes (a limit introduced in Shanghai _ 2023)
// model ref: LUSDST.sol (081024)
// NOTE: uint type precision ...
//  uint8 max = 255
//  uint16 max = ~65K -> 65,535
//  uint24 max = ~16M -> 16,777,216
//  uint32 max = ~4B -> 4,294,967,295
//  uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
pragma solidity ^0.8.24;


import "./ICallVault.sol"; // imports ICallLib.sol
// import "./ICallLib.sol";
import "./ICallConfig.sol";

// interface ICallitToken {
//     function ACCT_CALL_VOTE_LOCK_TIME(address _key) external view returns(uint256); // public
//     function EARNED_CALL_VOTES(address _key) external view returns(uint64); // public
//     // function mintCallToksEarned(address _receiver, uint256 _callAmntMint, uint64 _callVotesEarned, address _sender) external;
//     // function decimals() external pure returns (uint8);
//     // function pushAcctMarketReview(ICallLib.MARKET_REVIEW memory _marketReview, address _maker) external;
//     // function getMarketReviewsForMaker(address _maker) external view returns(ICallLib.MARKET_REVIEW[] memory);
//     function balanceOf_voteCnt(address _voter) external view returns(uint64);
// }

contract CallVoter {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    /* GLOBALS (CALLIT) */
    string public tVERSION = '0.0';
    bool private FIRST_ = true;
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallConfig private CONF; // set via CONF_setConfig
    ICallMarket private MARKET; // set via CONF_setConfig
    ICallLib private LIB;     // set via CONF_setConfig
    ICallVault private VAULT; // set via CONF_setConfig
    // ICallitDelegate private DELEGATE; // set via CONF_setConfig
    ICallitToken private CALL;  // set via CONF_setConfig

    // NOTE: required for voter hash algorithm (all need to be in the same contract)
    mapping(address => ICallLib.MARKET_VOTE[]) private ACCT_MARKET_VOTES; // store voter to their non-paid MARKET_VOTEs (ICallLib.MARKETs voted in) mapping (note: used & private until market close; live = false) ***
    mapping(address => ICallLib.MARKET_VOTE[]) public ACCT_MARKET_VOTES_PAID; // store voter to their 'paid' MARKET_VOTEs (ICallLib.MARKETs voted in) mapping (note: used & avail when market close; live = false) *
    mapping(address => uint64[]) private MARK_HASH_RESULT_VOTES; // store market hash to result vote counts array (note: keep private then set MARKET memeResultVotes after close);
    mapping(address => address) private ACCT_VOTER_HASH; // address hash used for generating _senderTicketHash in FACT.castVoteForMarketMeme
    uint64 private LIVE_MARKET_COUNT; // uint64 = max 18,000Q live tickets it can account for // MARKET set during LIVE_TICKETS_LST updates

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR
    /* -------------------------------------------------------- */
    constructor() {

    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.ADDR_DELEGATE() || msg.sender == CONF.KEEPER(), " !fact | del :+ ");
        _;
    }
    modifier onlyMARKET() {
        require(msg.sender == CONF.ADDR_MARKET() || msg.sender == CONF.KEEPER(), ' only MARKET :/ ');
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
        MARKET = ICallMarket(CONF.ADDR_MARKET());
        LIB = ICallLib(CONF.ADDR_LIB());
        VAULT = ICallVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
        // DELEGATE = ICallitDelegate(CONF.ADDR_DELEGATE());
        CALL = ICallitToken(CONF.ADDR_CALL());
    }
    function set_LIVE_MARKET_COUNT(uint64 _cnt) external onlyMARKET {
        LIVE_MARKET_COUNT = _cnt;
    }
    function getVoterHash(address _sender) external view onlyFactory returns(address) {
        // *WARNING* user must have their wallet conencted to use this function
        //  ie. read request must come from user's EOA and not the RPC server default assigned for 'view' requests
        require(_sender != address(0) && ACCT_VOTER_HASH[_sender] != address(0), ' no vote hash, call init :-/ ');
        return ACCT_VOTER_HASH[_sender];
    }
    function genVoterHash(address _sender) external onlyFactory {
        require(_sender != address(0) && ACCT_VOTER_HASH[_sender] == address(0), ' no _acct | prev-set :/ ');

        // Combine block properties with msg.sender to create a pseudo-random number
        uint256 rdm = uint256(keccak256(abi.encodePacked(
            block.timestamp,    // Current block timestamp
            blockhash(block.number - 1),  // Hash of the previous block
            _sender,          // Address of the transaction sender
            LIVE_MARKET_COUNT // local var seed (shouldn't be trackable w/in on-chain call stack)E
        )));
        // Truncate the random number to 160 bits (Ethereum address size)
        ACCT_VOTER_HASH[_sender] = address(uint160(rdm));

            // NOTE: this integration hides ticket address voting for from mempool/call-stack logs
            //     ie. they only see the _senderTicketHash generated 
            //         along w/ what market is being voted on
            //         but they can’t see which actual ticket
            //     note: if a malicious actor sees the code for genVoterHash
            //         then they can indeed figure out an EOA’s voter hash by reviewing 
            //          the chain’s call history for ‘genVoterHash’
            //          and replicating it using the seed params found inside the function code
            //         if they have an EOA’s voter hash, they can then loop through all 
            //          resultOptionTokens for the market (markHash) that was voted on,
            //          and retrieve the ticket address that _senderTicketHash references 
    }
    function moveMarketVoteToPaid(address _sender, uint64 _idxMove, ICallLib.MARKET_VOTE calldata _m_vote) external onlyFactory {
        // NOTE: move this market vote index '_idxMove', to paid
        // add this MARKET_VOTE to ACCT_MARKET_VOTES_PAID[msg.sender]
        // remove _idxMove MARKET_VOTE from ACCT_MARKET_VOTES[msg.sender]
        //  by replacing it with the last element (then popping last element)
        // NOTE: input MARKET_VOTE.paid should already be set to 'true'
        //  ie. this function simply 'moves', and does not 'set'
        ACCT_MARKET_VOTES_PAID[_sender].push(_m_vote);
        uint64 lastIdx = uint64(ACCT_MARKET_VOTES[_sender].length) - 1;
        if (_idxMove != lastIdx) { ACCT_MARKET_VOTES[_sender][_idxMove] = ACCT_MARKET_VOTES[_sender][lastIdx]; }
        ACCT_MARKET_VOTES[_sender].pop(); // Remove the last element (now a duplicate)
    }
    function getMarketVotesForAcct(address _account, bool _paid) external view returns(ICallLib.MARKET_VOTE[] memory) {
        require(_account != address(0), ' bad _account :{ ');
        if (!_paid) {
            require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.ADDR_DELEGATE(), ' only factory :0 ');
            return ACCT_MARKET_VOTES[_account];
        } else 
            return ACCT_MARKET_VOTES_PAID[_account];
    }
    function getResultVotesForMarketHash(address _markHash) external view onlyFactory returns(uint64[] memory) {
        // NOTE: this function is only called by 'FACT.closeMarketForTicket'
        //  this means it is indeed ok (here) to pass the vote results openly on-chain
        //  bc thats when the votes are released to public (during FACT.closeMarketForTicket)
        require(_markHash != address(0), ' bad _markHash :/ ');
        return MARK_HASH_RESULT_VOTES[_markHash];
    }
    function castVoteForMarketMeme(address _sender, address _senderMemeHash, address _markHash) external onlyFactory { // NOTE: !_deductFeePerc; reward mint
        // LEFT OF HERE ... 
        //  QUESTION: is there a need for hashing/hiding votes?
        //      in 'callit', voting was used to verify off-chain data (bring 'true' off-chain data... onto the chain)
        //          this included the requirement that only those who voted in the majority would receive rewards for voting
        //          this was meant to ensure that people vote 'honestly'
        //          hence, hiding votes was required to ensure that whale based voters couldn't see the majority leaning 
        //           in any one direction, then make a bet in the opposition & vote in that opposition & falsly earn majority of voter rewards
        //      in 'memeCall', voting is used to select a winning meme (nothing to do with off-chain data)
        //          SO, what happens if anyone can see the votes as they come in? can any manipulation or exploit occur?
        //            if not, do we need a seperate VOTE.sol contract that the public can't read / decompile to see the hash struct?

        // require(_sender != address(0) && _senderMemeHash != address(0) && _markHash != address(0), ' invalid input :-{=} ');
        require(ACCT_VOTER_HASH[_sender] != address(0), ' no voter hash for sender :-/ ');
        // require(IERC20(_ticket).balanceOf(msg.sender) == 0, ' no votes ;( ');

        // *WARNING* -> malicious actors could still monitor the chain activity (tx-by-tx)
        //    this function call potentially allows someone to manually track ticket counts as they come in
        //     (ie. a web page could be created that displays & tracks ticket votes as they come in)
        // HOWEVER, acquiring the source code for 'genVoterHash' is required ...
        //  if a malicious actor sees the code for genVoterHash
        //      then they can indeed figure out an EOA’s voter hash by reviewing 
        //      the chain’s call history for ‘genVoterHash’
        //      and replicating it using the seed params found inside the function code
        //  if they can replicate EOA voter hashes, they can then loop through all 
        //      resultOptionTokens for the market (markHash) that the EOAs voted on,
        //      and retrieve the ticket address that _senderTicketHash references 

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        ICallLib.MARKET memory mark = MARKET.getMarketForHash(_markHash);
        // require(mark.marketUsdAmnts.usdAmntPrizePool > 0, ' calls not closed yet :/ ');
        require(mark.dtSubmitDeadline < block.timestamp, ' submit deadline !passed yet :) ');
        require(mark.marketDatetimes.dtResultVoteStart <= block.timestamp && mark.marketDatetimes.dtResultVoteEnd > block.timestamp, ' not time to vote :p ');

        // get ticket address from _senderTicketHash
        //  loop through all tickets in _markHash
        //   find ticket where hash(msg.sender-voter-hash + ticket) == _senderTicketHash
        // address ticket;
        // uint16 tickIdx;
        address memeHash;
        uint16 memeIdx;
        // for (uint8 i=0; i < mark.marketResults.resultOptionTokens.length;){
        for (uint8 i=0; i < mark.marketSubmits.memeHashes.length;){
            address[] memory toHash = new address[](2);
            toHash[0] = ACCT_VOTER_HASH[_sender];
            // toHash[1] = mark.marketResults.resultOptionTokens[i];
            // address ticketHash = _genHashOfAddies(toHash);
            toHash[1] = mark.marketSubmits.memeHashes[i];
            address voteHash = _genHashOfAddies(toHash);

            // if (ticketHash == _senderMemeHash) {
            if (voteHash == _senderMemeHash) {
                // ticket = mark.marketResults.resultOptionTokens[i];
                // tickIdx = i;
                memeHash = mark.marketSubmits.memeHashes[i];
                memeIdx = i;
                break;
            }
                
            unchecked{i++;}
        }
        // require(ticket != address(0), ' bad ticket hash :/ '); // note: ticket holder check in LIB._addressIsMarketMakerOrCaller
        require(memeHash != address(0), ' bad _senderMemeHash :/ '); // note: ticket holder check in LIB._addressIsMarketMakerOrCaller
        // require(IERC20(ticket).balanceOf(msg.sender) == 0, ' no votes ;( ');

        // algorithmic logic...
        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        //  - store vote in struct MARKET_VOTE and push to ACCT_MARKET_VOTES

        //  - verify msg.sender is NOT this market's maker or meme submitter (ie. no self voting)
        // (bool is_maker, bool is_caller) = LIB._addressIsMarketMakerOrCaller(_sender, mark.maker, mark.marketResults.resultOptionTokens);
        (bool is_maker, bool is_submitter) = LIB.addressIsMarketMakerOrSubmitter(_sender, mark.maker, mark.marketSubmits.entryFeePaidEOAs);
        require(!is_maker && !is_submitter, ' no self-voting :o ');

        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        uint64 vote_cnt = LIB.getValidVoteCount(CALL.balanceOf_voteCnt(_sender), CONF.RATIO_CALL_TOK_PER_VOTE(), CALL.EARNED_CALL_VOTES(_sender), CALL.ACCT_CALL_VOTE_LOCK_TIME(_sender), mark.blockTimestamp);
        require(vote_cnt > 0, ' invalid voter :{=} ');
            // LEFT OFF HERE ... legacy integration ^ (needs change/verify working with MemeCall)

        //  - store vote in struct MARKET
        // mark.marketResults.resultTokenVotes[tickIdx] += vote_cnt; // NOTE: write to market
        // MARKET.setHashMarket(_markHash, mark, '');
        // MARK_HASH_RESULT_VOTES[_markHash][tickIdx] += vote_cnt; // NOTE: write
        MARK_HASH_RESULT_VOTES[_markHash][memeIdx] += vote_cnt; // NOTE: write
        

        // log market vote per EOA, so EOA can claim voter fees earned (where votes = "majority of votes / winning result option")
        //  NOTE: *WARNING* if ACCT_MARKET_VOTES was public, then anyone can see the votes before voting has ended
        ACCT_MARKET_VOTES[_sender].push(ICallLib.MARKET_VOTE(_sender, ticket, tickIdx, vote_cnt, mark.maker, mark.marketNum, mark.marketHash, false)); // false = un-paid
            // LEFT OFF HERE ... legacy integration ^ (needs change/verify working with MemeCall)

        // // mint $CALL token reward to msg.sender
        // _mintCallToksEarned(_sender, CONF.RATIO_CALL_MINT_PER_VOTE()); // emit CallTokensEarned

        // event MarketTicketVote

        // NOTE: -> DO NOT want to emit event log for casting votes 
        //  this will allow people to see majority votes before voting        
    }

    /* -------------------------------------------------------- */
    /* PRIVATE
    /* -------------------------------------------------------- */
    function _genHashOfAddies(address[] memory addies) private pure returns (address) {
        // Initialize a bytes array for encoding
        bytes memory data;

        // Loop through each address in the array and append it to the data
        for (uint i = 0; i < addies.length; i++) {
            data = abi.encodePacked(data, addies[i]);
        }

        // // Append the UID string to the encoded data
        // data = abi.encodePacked(data, uid);

        // Hash the concatenated data
        bytes32 hash = keccak256(data);

        // Cast the resulting hash to an address, similar to before
        address hashAddy = address(uint160(uint256(hash))); // note: triple cast correct & required
        return hashAddy;
    }
}