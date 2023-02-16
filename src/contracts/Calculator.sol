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

  function getAUM(bool isMaxPrice) public view returns (uint256) {
    // TODO  pendingBorrowingFee
    // plpAUM = value of all asset + pnlShort + pnlLong + pendingBorrowingFee
    uint256 pendingBorrowingFee = 0;
    int256 pnl = _getGlobalPNL();

    uint256 aum = _getPLPValue(isMaxPrice) + pendingBorrowingFee;
    if (pnl < 0) {
      uint256 _pnl = uint256(-pnl);
      if (aum < _pnl) return 0;
      aum -= _pnl;
    } else {
      aum += uint256(pnl);
    }

    return aum;
  }

  function _getPLPValue(bool isMaxPrice) internal view returns (uint256) {
    uint256 assetValue = 0;
    address _plpUnderlyingToken = IConfigStorage(configStorage)
      .getNextAcceptedToken(
        IConfigStorage(configStorage).ITERABLE_ADDRESS_LIST_START()
      );

    while (
      _plpUnderlyingToken !=
      IConfigStorage(configStorage).getNextAcceptedToken(
        IConfigStorage(configStorage).ITERABLE_ADDRESS_LIST_END()
      )
    ) {
      (uint priceE30, ) = IOracleMiddleware(oracle).getLatestPrice(
        _plpUnderlyingToken.toBytes32(),
        isMaxPrice,
        IConfigStorage(configStorage)
          .getMarketConfigByToken(_plpUnderlyingToken)
          .priceConfidentThreshold
      );

      uint value = (IVaultStorage(vaultStorage).plpLiquidity(
        _plpUnderlyingToken
      ) * priceE30) / (10 ** ERC20(_plpUnderlyingToken).decimals());

      unchecked {
        assetValue += value;
      }
      _plpUnderlyingToken = IConfigStorage(configStorage).getNextAcceptedToken(
        _plpUnderlyingToken
      );
    }

    return assetValue;
  }

  function getPLPPrice(
    uint256 aum,
    uint256 plpSupply
  ) public pure returns (uint256) {
    if (plpSupply == 0) return 0;
    return aum / plpSupply;
  }

  function _getGlobalPNL() internal view returns (int256) {
    // TODO:: REFACTOR if someone dont want totalPnlLong and short.
    int256 totalPnlLong = 0;
    int256 totalPnlShort = 0;
    for (
      uint256 i = 0;
      i < IConfigStorage(configStorage).getMarketConfigsLength();

    ) {
      IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
        configStorage
      ).getMarketConfigs(i);

      IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
        .getGlobalMarkets(i);

      int256 _pnlLongE30 = 0;
      int256 _pnlShortE30 = 0;

      //TODO validate timestamp of these
      (uint priceE30Long, ) = IOracleMiddleware(oracle).getLatestPrice(
        marketConfig.assetId,
        false,
        marketConfig.priceConfidentThreshold
      );

      (uint priceE30Short, ) = IOracleMiddleware(oracle).getLatestPrice(
        marketConfig.assetId,
        true,
        marketConfig.priceConfidentThreshold
      );

      //TODO validate price, revert when crypto price stale, stock use Lastprice

      if (
        _globalMarket.globalLongAvgPrice > 0 && _globalMarket.globalLongSize > 0
      ) {
        // reduce loop
        _pnlLongE30 =
          int256(priceE30Long) -
          (int256(_globalMarket.globalLongAvgPrice) * 1e30) /
          (int256(_globalMarket.globalLongAvgPrice) *
            int256(_globalMarket.globalLongSize));
      }

      // TODO DOUBLE CHECK :: ask team globalMarket.globalShortSize store in negative???
      if (
        _globalMarket.globalShortAvgPrice > 0 &&
        _globalMarket.globalShortSize > 0
      ) {
        _pnlShortE30 =
          ((int256(_globalMarket.globalShortAvgPrice) - int256(priceE30Short)) *
            1e30) /
          (int256(_globalMarket.globalShortAvgPrice) *
            int256(_globalMarket.globalShortSize));
      }

      {
        unchecked {
          i++;
          totalPnlLong += _pnlLongE30;
          totalPnlShort += _pnlShortE30;
        }
      }
    }

    return totalPnlLong + totalPnlShort;
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
    uint256 _tokenValueE30,
    IConfigStorage _configStorage,
    IVaultStorage _vaultStorage
  ) external returns (uint256) {
    if (!_configStorage.getLiquidityConfig().dynamicFeeEnabled) {
      return _configStorage.getLiquidityConfig().depositFeeRate;
    }

    return
      _getFeeRate(
        _tokenValueE30,
        _vaultStorage.plpLiquidityUSDE30(_token),
        _vaultStorage.plpTotalLiquidityUSDE30(),
        _configStorage.getLiquidityConfig(),
        _configStorage.getPLPTokenConfig(_token),
        LiquidityDirection.ADD
      );
  }

  function getRemoveLiquidityFeeRate(
    address _token,
    uint256 _tokenValueE30,
    IConfigStorage _configStorage,
    IVaultStorage _vaultStorage
  ) external returns (uint256) {
    if (!_configStorage.getLiquidityConfig().dynamicFeeEnabled) {
      return _configStorage.getLiquidityConfig().withdrawFeeRate;
    }

    return
      _getFeeRate(
        _tokenValueE30,
        _vaultStorage.plpLiquidityUSDE30(_token),
        _vaultStorage.plpTotalLiquidityUSDE30(),
        _configStorage.getLiquidityConfig(),
        _configStorage.getPLPTokenConfig(_token),
        LiquidityDirection.REMOVE
      );
  }

  function _getFeeRate(
    uint256 _value,
    uint256 _liquidityUSD, //e30
    uint256 _totalLiquidityUSD, //e30
    IConfigStorage.LiquidityConfig memory _liquidityConfig,
    IConfigStorage.PLPTokenConfig memory _plpTokenConfig,
    LiquidityDirection direction
  ) internal pure returns (uint256) {
    uint256 _feeRate = direction == LiquidityDirection.ADD
      ? _liquidityConfig.depositFeeRate
      : _liquidityConfig.withdrawFeeRate;
    uint256 _taxRate = _liquidityConfig.taxFeeRate;
    uint256 _totalTokenWeight = _liquidityConfig.plpTotalTokenWeight;

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

    // TODO move this to service
    uint256 _nextWeight = (nextValue * 1e18) / targetValue;
    // if weight exceed targetWeight(e18) + maxWeight(e18)
    if (
      _nextWeight > _plpTokenConfig.targetWeight + _plpTokenConfig.maxWeightDiff
    ) {
      revert ICalculator_PoolImbalance();
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
