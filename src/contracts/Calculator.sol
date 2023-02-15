// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ICalculator } from "./interfaces/ICalculator.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Calculator is ICalculator {
  uint256 internal constant MAX_RATE = 1e18;
  // using libs for type
  using AddressUtils for address;

  // STATES
  address public oracle;
  address public vaultStorage;
  address public configStorage;
  address public perpStorage;

  constructor(
    address _oracle,
    address _vaultStorage,
    address _perpStorage,
    address _configStorage
  ) {
    // @todo - Sanity check
    if (
      _oracle == address(0) ||
      _vaultStorage == address(0) ||
      _perpStorage == address(0) ||
      _configStorage == address(0)
    ) revert ICalculator_InvalidAddress();
    oracle = _oracle;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    perpStorage = _perpStorage;
  }

  function getAUM(bool isMaxPrice) public returns (uint256) {
    // TODO assetValue, pendingBorrowingFee
    // plpAUM = value of all asset + pnlShort + pnlLong + pendingBorrowingFee
    uint256 pendingBorrowingFee = 0;
    return
      _getPLPValue(isMaxPrice) +
      _getGlobalPNL(PositionExposure.LONG) +
      _getGlobalPNL(PositionExposure.SHORT) +
      pendingBorrowingFee;
  }

  function _getPLPValue(bool isMaxPrice) internal view returns (uint256) {
    uint256 assetValue = 0;
    for (
      uint i = 0;
      i <
      IConfigStorage(configStorage).getLiquidityConfig().acceptedTokens.length;

    ) {
      address token = IConfigStorage(configStorage)
        .getLiquidityConfig()
        .acceptedTokens[i];

      (uint priceE30, ) = IOracleMiddleware(oracle).getLatestPrice(
        token.toBytes32(),
        isMaxPrice,
        IConfigStorage(configStorage)
          .getMarketConfigByToken(token)
          .priceConfidentThreshold
      );

      uint value = (IVaultStorage(vaultStorage).plpLiquidity(token) *
        priceE30) / (10 ** ERC20(token).decimals());

      unchecked {
        assetValue += value;
        i++;
      }
    }
    return assetValue;
  }

  function getPLPPrice(
    uint256 aum,
    uint256 plpSupply
  ) public pure returns (uint256) {
    return aum / plpSupply;
  }

  function _getGlobalPNL(
    PositionExposure _exposure
  ) internal view returns (uint256) {
    if (_exposure == PositionExposure.LONG) {
      for (
        uint256 i = 0;
        i < IConfigStorage(configStorage).getMarketConfigsLength();

      ) {
        //TODO FIXME continue coding here
      }
    }
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
    uint256 _value,
    uint256 _liquidityUSD, //e18
    uint256 _totalLiquidityUSD, //e18
    uint256 _totalTokenWeight,
    IConfigStorage.LiquidityConfig memory _liquidityConfig,
    IConfigStorage.PLPTokenConfig memory _plpTokenConfig,
    LiquidityDirection direction
  ) internal pure returns (uint256) {
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

  function getCollateralValue(
    address _subAccount
  ) public view returns (uint collateralValueE30) {
    // Get list of current depositing tokens on trader's account
    address[] memory traderTokens = IVaultStorage(vaultStorage).getTraderTokens(
      _subAccount
    );

    // Loop through list of current depositing tokens
    for (uint i; i < traderTokens.length; ) {
      address token = traderTokens[i];

      //Get token decimals from ConfigStorage
      uint decimals = IConfigStorage(configStorage)
        .getCollateralTokenConfigs(token)
        .decimals;

      //Get priceConfidentThreshold from ConfigStorage
      uint priceConfidenceThreshold = IConfigStorage(configStorage)
        .getMarketConfigByToken(token)
        .priceConfidentThreshold;

      // Get current collateral token balance of trader's account
      uint amount = IVaultStorage(vaultStorage).traderBalances(
        _subAccount,
        token
      );

      bool isMaxPrice = false; // @note Collateral value always use Min price
      // Get price from oracle
      // @todo - validate price age
      (uint priceE30, ) = IOracleMiddleware(oracle).getLatestPrice(
        token.toBytes32(),
        isMaxPrice,
        priceConfidenceThreshold
      );

      // Calculate accumulative value of collateral tokens
      collateralValueE30 += (amount * priceE30) / 10 ** decimals;

      unchecked {
        i++;
      }
    }
  }
}
