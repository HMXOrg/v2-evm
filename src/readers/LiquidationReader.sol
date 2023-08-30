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
  IPerpStorage public perpStorage;
  ICalculator public calculator;

  constructor(address _perpStorage, address _calculator) {
    perpStorage = IPerpStorage(_perpStorage);
    calculator = ICalculator(_calculator);
  }

  function getLiquidatableSubAccount(
    uint64 _limit,
    uint64 _offset,
    bytes32[] memory _assetIds,
    uint64[] memory _prices,
    bool[] memory _shouldInverts
  ) external view returns (address[] memory) {
    address[] memory subAccounts = perpStorage.getActiveSubAccounts(_limit, _offset);

    uint256[] memory prices;
    uint256 len = _prices.length;
    prices = new uint256[](len);
    for (uint256 i = 0; i < len; i++) {
      if (_assetIds[i] == bytes32(abi.encodePacked("GLP"))) {
        prices[i] = uint256(_prices[i]) * 1e22;
        continue;
      }
      prices[i] = _convertPrice(_prices[i], _shouldInverts[i]);
    }

    len = subAccounts.length;
    address[] memory liquidatableSubAccounts = new address[](len);
    for (uint256 i = 0; i < len; i++) {
      int256 _equityValueE30 = calculator.getEquityWithInjectedPrices(subAccounts[i], _assetIds, prices);
      uint256 _mmrValueE30 = calculator.getMMR(subAccounts[i]);

      bool _shouldLiquidate = _checkLiquidate(_equityValueE30, _mmrValueE30);
      if (_shouldLiquidate) {
        liquidatableSubAccounts[i] = subAccounts[i];
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
