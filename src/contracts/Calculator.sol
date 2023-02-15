// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ICalculator } from "./interfaces/ICalculator.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";

contract Calculator is ICalculator {
  uint256 internal constant MAX_RATE = 1e18;

  function getAUM() public view returns (uint256) {
    // TODO assetValue, pendingBorrowingFee
    // plpAUM = value of all asset + pnlShort + pnlLong + pendingBorrowingFee
    uint256 assetValue = 0;
    uint256 pendingBorrowingFee = 0;
    return
      assetValue +
      _getPLPPnl(PositionExposure.LONG) +
      _getPLPPnl(PositionExposure.SHORT) +
      pendingBorrowingFee;
  }

  function getPLPPrice(
    uint256 aum,
    uint256 plpSupply
  ) public pure returns (uint256) {
    return aum / plpSupply;
  }

  function _getPLPPnl(
    PositionExposure _exposure
  ) internal pure returns (uint256) {
    //TODO calculate pnl short and long
    return 0;
  }

  function getMintAmount(
    uint256 _aum,
    uint256 _totalSupply,
    uint256 _amount
  ) public pure returns (uint256) {
    return _aum == 0 ? _amount : (_amount * _totalSupply) / _aum;
  }

  function convertTokenDecimals(
    uint256 fromTokenDecimals,
    uint256 toTokenDecimals,
    uint256 amount
  ) public pure returns (uint256) {
    return (amount * 10 ** toTokenDecimals) / 10 ** fromTokenDecimals;
  }

  function getAddLiquidityFeeRate(
    address _token,
    uint256 _tokenValue, //e18
    IConfigStorage _configStorage,
    IVaultStorage _vaultStorage
  ) external returns (uint256) {
    if (!_configStorage.getLiquidityConfig().dynamicFeeEnabled) {
      return _configStorage.getLiquidityConfig().depositFeeRate;
    }

    return
      _getFeeRate(
        _token,
        _tokenValue,
        _vaultStorage.plpLiquidityUSD(_token),
        _vaultStorage.plpTotalLiquidityUSD(),
        _configStorage.plpTotalTokenWeight(),
        _configStorage.getLiquidityConfig(),
        _configStorage.getPLPTokenConfig(_token),
        LiquidityDirection.ADD
      );
  }

  function _getFeeRate(
    address _token,
    uint256 _value,
    uint256 _liquidityUSD, //e18
    uint256 _totalLiquidityUSD, //e18
    uint256 _totalTokenWeight,
    IConfigStorage.LiquidityConfig memory _liquidityConfig,
    IConfigStorage.PLPTokenConfig memory _plpTokenConfig,
    LiquidityDirection direction
  ) internal view returns (uint256) {
    uint256 _feeRate = _liquidityConfig.depositFeeRate;
    uint256 _taxRate = _liquidityConfig.taxFeeRate;

    uint256 startValue = _liquidityUSD;
    uint256 nextValue = startValue + _value;
    if (direction == LiquidityDirection.REMOVE)
      nextValue = _value > startValue ? 0 : startValue - _value;

    uint256 targetValue = _getTargetValue(
      _totalLiquidityUSD,
      _plpTokenConfig.targetWeight,
      _totalTokenWeight
    );
    if (targetValue == 0) return _feeRate;

    uint256 startTargetDiff = startValue > targetValue
      ? startValue - targetValue
      : targetValue - startValue;

    uint256 nextTargetDiff = nextValue > targetValue
      ? nextValue - targetValue
      : targetValue - nextValue;

    // nextValue moves closer to the targetValue -> positive case;
    // Should apply rebate.
    if (nextTargetDiff < startTargetDiff) {
      uint256 rebateRate = (_taxRate * startTargetDiff) / targetValue;
      return rebateRate > _feeRate ? 0 : _feeRate - rebateRate;
    }

    // If not then -> negative impact to the pool.
    // Should apply tax.
    uint256 midDiff = (startTargetDiff + nextTargetDiff) / 2;
    if (midDiff > targetValue) {
      midDiff = targetValue;
    }
    _taxRate = (_taxRate * midDiff) / targetValue;

    return _feeRate + _taxRate;
  }

  // return in e18
  function _getTargetValue(
    uint256 totalLiquidityUSD, //e18
    uint256 tokenWeight,
    uint256 totalTokenWeight
  ) public pure returns (uint256) {
    if (totalLiquidityUSD == 0) return 0;

    return (totalLiquidityUSD * tokenWeight) / totalTokenWeight;
  }
}
