// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ICallMarket {
    // accessors
    function getMarketCntForMaker(address _maker) external view returns(uint256);

    // mutators
    function storeNewMarket(ICallitLib.MARKET memory _mark, address _maker) external;
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