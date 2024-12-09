// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./ICallitLib.sol";

interface ICallitVault {
    function payPromoUsdReward(address _sender, address _promoCodeHash, uint64 _usdReward, address _receiver) external returns(uint64);
    function exeArbPriceParityForTicket(ICallitLib.MARKET memory mark, uint16 tickIdx, address _sender) external returns(uint64, uint64, uint64, uint64, uint64);
    // function deposit(address _depositor) external payable;
    function deposit(address _depositor, address _altToken, uint256 _altAmnt) external payable returns(uint64);
    
    // NOTE: legacy private (now public)
    function _usd_decimals() external pure returns (uint8);
    function _payUsdReward(address _sender, uint64 _usdReward, address _receiver) external;
    function createDexLP(address _sender, uint256 _markNum, string[] calldata _resultLabels, uint256 _net_usdAmntLP, uint32 _ratioLpTokPerUsd) external returns(ICallitLib.MARKET_RESULTS memory);
    function _exePullLiquidityFromLP(address _tokenRouter, address _pairAddress, address _token, address _usdStable) external returns(uint256);

    // NOTE: callit market management
    function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok, address _buyer) external returns(uint64, uint256);
}