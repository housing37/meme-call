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


contract MemeCall {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */


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
    // ref: SDD_meme-comp_112524_1855.pdf
    // Any “Voter” may create a competition
    // - they choose any topic (ie. “best meme to support $BEAR on PulseChain”)
    // - they set a USD amount entry fee (ie. $10.00)
    // - they set a submission time frame + voting time aloud (ie. 1 week to submit memes + 24hrs for voting)
    function createNewMemeCall() external {

    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // The public may freely view a list of open competitions on the dapp
    // - “Meme Creators” choose one to participate in & submit a url link to their meme
    // - the url may be from any social media or HTTP server in the world, etc.
    // - they must also pay the entry free along with their submission
    // - can pay in any ERC20 token (amnt value must = the USD entry fee amnt)
    function submitMemeCallEntry() external {

    }

    // ref: SDD_meme-comp_112524_1855.pdf
    // After voting is complete for any given competition (ie. the competition is now ‘closed’) 
    // - “Voters” then use the dapp to claim their rewards for voting
    //      rewards: small percent of prize pool + minted voter tokens 
    function claimRewardVoter() external onlyVoter {
        // ref: SDD_meme-comp_112524_1855.pdf
        // - voters get minted 'some amount’ of voter token for each competition vote 
        // - voters earn a small % of each prize pool they voted in
        //      note: the ‘competition maker’ earns an extra small % of that prize pool
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


}