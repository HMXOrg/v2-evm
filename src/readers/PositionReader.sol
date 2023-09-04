// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// interfaces
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

// contract
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

// libs
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { SqrtX96Codec } from "@hmx/libraries/SqrtX96Codec.sol";
import { TickMath } from "@hmx/libraries/TickMath.sol";

contract PositionReader {
  IConfigStorage immutable configStorage;
  IPerpStorage immutable perpStorage;
  IOracleMiddleware immutable oracleMiddleware;
  ICalculator immutable calculator;

  error PositionReader_InvalidArray();

  constructor(address _configStorage, address _perpStorage, address _oracleMiddleware, address _calculator) {
    configStorage = IConfigStorage(_configStorage);
    perpStorage = IPerpStorage(_perpStorage);
    oracleMiddleware = IOracleMiddleware(_oracleMiddleware);
    calculator = ICalculator(_calculator);
  }

  /// @notice Get the force-take max profitable position IDs.
  /// @param _activePositionLimit The maximum number of position IDs to retrieve.
  /// @param _activePositionOffset The offset for fetching position IDs.
  /// @param _pricesE8 An array of prices in E8 format.
  /// @param _shouldInverts An array of boolean values indicating whether to invert prices.
  /// @return forceTakeMaxProfitablePositionIds An array of position IDs that meet the criteria.
  function getForceTakeMaxProfitablePositionIds(
    uint64 _activePositionLimit,
    uint64 _activePositionOffset,
    uint64[] memory _pricesE8,
    bool[] memory _shouldInverts
  ) external view returns (bytes32[] memory) {
    if (_pricesE8.length != _shouldInverts.length) revert PositionReader_InvalidArray();

    // Convert prices from E8 to E30 format.
    uint256 len = _pricesE8.length;
    uint256[] memory pricesE30 = new uint256[](len);
    for (uint256 i; i < len; ) {
      pricesE30[i] = _convertPrice(_pricesE8[i], _shouldInverts[i]);
      unchecked {
        ++i;
      }
    }

    // Get active position IDs based on the provided limit and offset.
    bytes32[] memory positionIds = perpStorage.getActivePositionIds(_activePositionLimit, _activePositionOffset);
    len = positionIds.length;
    bytes32[] memory forceTakeMaxProfitablePositionIds = new bytes32[](len);
    // Iterate through each position ID to check if it's max profitable.
    for (uint256 i; i < len; ) {
      IPerpStorage.Position memory position = perpStorage.getPositionById(positionIds[i]);
      IConfigStorage.MarketConfig memory marketConfig = configStorage.getMarketConfigByIndex(position.marketIndex);
      PerpStorage.Market memory market = perpStorage.getMarketByIndex(position.marketIndex);

      // Get the latest adaptive price for the position.
      (uint256 _adaptivePriceE30, ) = oracleMiddleware.unsafeGetLatestAdaptivePrice(
        marketConfig.assetId,
        true,
        (int(market.longPositionSize) - int(market.shortPositionSize)),
        -position.positionSizeE30,
        marketConfig.fundingRate.maxSkewScaleUSD,
        pricesE30[position.marketIndex]
      );

      // Calculate the delta
      (bool _isProfit, uint256 _delta) = calculator.getDelta(
        HMXLib.abs(position.positionSizeE30),
        position.positionSizeE30 > 0,
        _adaptivePriceE30,
        position.avgEntryPriceE30,
        position.lastIncreaseTimestamp,
        position.marketIndex
      );
      // Check if it's a max profitable position.
      bool isMaxProfit = _checkMaxProfit(_isProfit, _delta, position.reserveValueE30);
      if (isMaxProfit) {
        forceTakeMaxProfitablePositionIds[i] = positionIds[i];
      }

      unchecked {
        ++i;
      }
    }

    return forceTakeMaxProfitablePositionIds;
  }

  function _checkMaxProfit(bool _isProfit, uint256 _delta, uint256 _reserveValueE30) internal pure returns (bool) {
    return _isProfit && _delta > _reserveValueE30;
  }

  function _convertPrice(uint64 _priceE8, bool _shouldInvert) internal pure returns (uint256) {
    uint160 _priceE18 = SqrtX96Codec.encode(uint(_priceE8) * 10 ** uint32(10));
    int24 _tick = TickMath.getTickAtSqrtRatio(_priceE18);
    uint160 _sqrtPriceX96 = TickMath.getSqrtRatioAtTick(_tick);
    uint256 _spotPrice = SqrtX96Codec.decode(_sqrtPriceX96);
    uint256 _priceE30 = _spotPrice * 1e12;

    if (!_shouldInvert) return _priceE30;

    if (_priceE30 == 0) return 0;
    return 10 ** 60 / _priceE30;
  }
}
