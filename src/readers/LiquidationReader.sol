// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// interfaces
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

// libs
import { SqrtX96Codec } from "@hmx/libraries/SqrtX96Codec.sol";
import { TickMath } from "@hmx/libraries/TickMath.sol";

contract LiquidationReader {
  IPerpStorage immutable perpStorage;
  ICalculator immutable calculator;

  error LiquidationReader_InvalidArray();

  constructor(address _perpStorage, address _calculator) {
    perpStorage = IPerpStorage(_perpStorage);
    calculator = ICalculator(_calculator);
  }

  /// @notice Get the liquidatable sub-accounts.
  /// @param _limit The maximum number of sub-accounts to retrieve.
  /// @param _offset The offset for fetching sub-accounts.
  /// @param _assetIds An array of asset IDs.
  /// @param _pricesE8 An array of prices in E8 format corresponding to the asset IDs.
  /// @param _shouldInverts An array of boolean values indicating whether to invert prices for the asset IDs.
  /// @return liquidatableSubAccounts An array of sub-account addresses that meet the liquidation criteria.
  function getLiquidatableSubAccount(
    uint64 _limit,
    uint64 _offset,
    bytes32[] memory _assetIds,
    uint64[] memory _pricesE8,
    bool[] memory _shouldInverts
  ) external view returns (address[] memory) {
    if (_assetIds.length != _pricesE8.length || _pricesE8.length != _shouldInverts.length)
      revert LiquidationReader_InvalidArray();

    // Get active sub-accounts based on the provided limit and offset.
    address[] memory subAccounts = perpStorage.getActiveSubAccounts(_limit, _offset);

    // Convert prices from E8 to E30 format.
    uint256[] memory pricesE30;
    uint256 len = _pricesE8.length;
    pricesE30 = new uint256[](len);
    for (uint256 i; i < len; ) {
      if (_assetIds[i] == bytes32(abi.encodePacked("GLP"))) {
        pricesE30[i] = uint256(_pricesE8[i]) * 1e22;
        continue;
      }
      pricesE30[i] = _convertPrice(_pricesE8[i], _shouldInverts[i]);

      unchecked {
        ++i;
      }
    }

    len = subAccounts.length;
    address[] memory liquidatableSubAccounts = new address[](len);
    // Iterate through each sub-account to check if it's liquidatable.
    for (uint256 i; i < len; ) {
      // Calculate the equity value and MMR for the sub-account.
      int256 _equityValueE30 = calculator.getEquityWithInjectedPrices(subAccounts[i], _assetIds, pricesE30);
      uint256 _mmrValueE30 = calculator.getMMR(subAccounts[i]);

      // Check if the sub-account should be liquidated based on criteria.
      bool _shouldLiquidate = _checkLiquidate(_equityValueE30, _mmrValueE30);
      if (_shouldLiquidate) {
        liquidatableSubAccounts[i] = subAccounts[i];
      }

      unchecked {
        ++i;
      }
    }

    return liquidatableSubAccounts;
  }

  function _checkLiquidate(int256 _equityValueE30, uint256 _mmrValueE30) internal pure returns (bool) {
    return _equityValueE30 < 0 || uint256(_equityValueE30) < _mmrValueE30;
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
