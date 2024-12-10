// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./ICallLib.sol";
interface ICallVoter {
    // accessors
    function getVoterHash(address _sender) external view returns(address);
    function getResultVotesForMarketHash(address _markHash) external view returns(uint64[] memory);
    function getMarketVotesForAcct(address _account, bool _paid) external view returns(ICallLib.MARKET_VOTE[] memory);

    // mutators
    function genVoterHash(address _sender) external;
    function set_LIVE_MARKET_COUNT(uint64 _cnt) external;
    function castVoteForMarketTicket(address _sender, address _senderTicketHash, address _markHash) external;
    function moveMarketVoteToPaid(address _sender, uint64 _idxMove, ICallLib.MARKET_VOTE calldata _m_vote) external;
}
interface ICallMarket {
    // accessors
    function getMarketCntForMaker(address _maker) external view returns(uint256);
    function getMarketForHash(address _hash) external view returns(ICallLib.MARKET memory);

    // mutators
    function storeNewMarket(ICallLib.MARKET memory _mark, address _maker) external;
}
interface ICallConfig {
    // accessors
    function KEEPER() external view returns(address);
    function USE_SEC_DEFAULT_VOTE_TIME() external view returns(bool);
    function SEC_DEFAULT_VOTE_TIME() external view returns(uint256);
    function ADDR_LIB() external view returns(address);
    // function ADDR_VAULT() external view returns(address);
    // function ADDR_DELEGATE() external view returns(address);
    // function ADDR_CALL() external view returns(address);
    // function ADDR_FACT() external view returns(address);
    function ADDR_MARKET() external view returns(address);
    // function ADDR_VOTER() external view returns(address);

    function MAX_EOA_MARKETS() external view returns(uint64);

    // mutators
    //  ...
}