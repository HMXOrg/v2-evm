// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "../../src/storages/interfaces/IPerpStorage.sol";

contract MockPerpStorage {
  mapping(address => IPerpStorage.Position[]) public positions;
  mapping(uint256 => IPerpStorage.GlobalMarket) public globalMarkets;

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================
  function getGlobalMarketInfo(
    uint256 _marketIndex
  ) external view returns (int256 accumFundingRateLong, int256 accumFundingRateShort) {
    return (globalMarkets[_marketIndex].accumFundingRateLong, globalMarkets[_marketIndex].accumFundingRateShort);
  }

  function getPositionBySubAccount(
    address _subAccount
  ) external view returns (IPerpStorage.Position[] memory traderPositions) {
    return positions[_subAccount];
  }

  function getGlobalMarketByIndex(uint256 _marketIndex) external view returns (IPerpStorage.GlobalMarket memory) {
    return globalMarkets[_marketIndex];
  }

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================

  function setPositionBySubAccount(address _subAccount, IPerpStorage.Position memory _position) external {
    positions[_subAccount].push(_position);
  }

  // @todo - update funding rate
  function updateGlobalLongMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest,
    int256 _newAccumFundingRateLong,
    int256 _currentFundingRate
  ) external {
    globalMarkets[_marketIndex].longPositionSize = _newPositionSize;
    globalMarkets[_marketIndex].longAvgPrice = _newAvgPrice;
    globalMarkets[_marketIndex].longOpenInterest = _newOpenInterest;
    globalMarkets[_marketIndex].accumFundingRateLong = _newAccumFundingRateLong;
    globalMarkets[_marketIndex].currentFundingRate = _currentFundingRate;
  }

  // @todo - update funding rate
  function updateGlobalShortMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest,
    int256 _newAccumFundingRateShort,
    int256 _currentFundingRate
  ) external {
    globalMarkets[_marketIndex].shortPositionSize = _newPositionSize;
    globalMarkets[_marketIndex].shortAvgPrice = _newAvgPrice;
    globalMarkets[_marketIndex].shortOpenInterest = _newOpenInterest;
    globalMarkets[_marketIndex].accumFundingRateShort = _newAccumFundingRateShort;
    globalMarkets[_marketIndex].currentFundingRate = _currentFundingRate;
  }
}
