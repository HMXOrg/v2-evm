// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "../../src/storages/interfaces/IPerpStorage.sol";

contract MockPerpStorage {
  mapping(address => IPerpStorage.Position[]) public positions;
  mapping(uint256 => IPerpStorage.GlobalMarket) public globalMarkets;
  mapping(bytes32 => IPerpStorage.Position) public positionById;

  /**
   * Getter
   */
  function getGlobalMarketInfo(
    uint256 _marketIndex
  ) external view returns (int256 accumFundingLong, int256 accumFundingShort) {
    IPerpStorage.GlobalMarket memory _globalMarket = globalMarkets[_marketIndex];
    return (_globalMarket.accumFundingLong, _globalMarket.accumFundingShort);
  }

  function getPositionBySubAccount(
    address _subAccount
  ) external view returns (IPerpStorage.Position[] memory traderPositions) {
    return positions[_subAccount];
  }

  function getPositionById(bytes32 _positionId) external view returns (IPerpStorage.Position memory) {
    return positionById[_positionId];
  }

  function _getPositionId(address _account, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  function getGlobalMarketByIndex(uint256 _marketIndex) external view returns (IPerpStorage.GlobalMarket memory) {
    return globalMarkets[_marketIndex];
  }

  /**
   * Setter
   */

  function setPositionBySubAccount(address _subAccount, IPerpStorage.Position memory _position) external {
    positions[_subAccount].push(_position);
    positionById[_getPositionId(_subAccount, _position.marketIndex)] = _position;
  }

  // @todo - update funding rate
  function updateGlobalLongMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest,
    int256 _newAccumFundingLong,
    int256 _currentFundingRate
  ) external {
    globalMarkets[_marketIndex].longPositionSize = _newPositionSize;
    globalMarkets[_marketIndex].longAvgPrice = _newAvgPrice;
    globalMarkets[_marketIndex].longOpenInterest = _newOpenInterest;
    globalMarkets[_marketIndex].accumFundingLong = _newAccumFundingLong;
    globalMarkets[_marketIndex].currentFundingRate = _currentFundingRate;
  }

  // @todo - update funding rate
  function updateGlobalShortMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest,
    int256 _newAccumFundingShort,
    int256 _currentFundingRate
  ) external {
    globalMarkets[_marketIndex].shortPositionSize = _newPositionSize;
    globalMarkets[_marketIndex].shortAvgPrice = _newAvgPrice;
    globalMarkets[_marketIndex].shortOpenInterest = _newOpenInterest;
    globalMarkets[_marketIndex].accumFundingShort = _newAccumFundingShort;
    globalMarkets[_marketIndex].currentFundingRate = _currentFundingRate;
  }
}
