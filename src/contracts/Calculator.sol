// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { Owned } from "@hmx/base/Owned.sol";

//contracts
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
// Interfaces
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract Calculator is Owned, ICalculator {
  uint32 internal constant BPS = 1e4;
  uint64 internal constant ETH_PRECISION = 1e18;
  uint64 internal constant RATE_PRECISION = 1e18;

  // EVENTS
  event LogSetOracle(address indexed oldOracle, address indexed newOracle);
  event LogSetVaultStorage(address indexed oldVaultStorage, address indexed vaultStorage);
  event LogSetConfigStorage(address indexed oldConfigStorage, address indexed configStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address indexed perpStorage);

  // STATES
  // @todo - move oracle config to storage
  address public oracle;
  address public vaultStorage;
  address public configStorage;
  address public perpStorage;

  constructor(address _oracle, address _vaultStorage, address _perpStorage, address _configStorage) {
    // Sanity check
    if (
      _oracle == address(0) || _vaultStorage == address(0) || _perpStorage == address(0) || _configStorage == address(0)
    ) revert ICalculator_InvalidAddress();

    PerpStorage(_perpStorage).getGlobalState();
    VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
    ConfigStorage(_configStorage).getLiquidityConfig();

    oracle = _oracle;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    perpStorage = _perpStorage;
  }

  /// @notice getAUME30
  /// @param _isMaxPrice Use Max or Min Price
  /// @return PLP Value in E18 format
  function getAUME30(bool _isMaxPrice) external view returns (uint256) {
    // plpAUM = value of all asset + pnlShort + pnlLong + pendingBorrowingFee
    uint256 pendingBorrowingFeeE30 = _getPendingBorrowingFeeE30();
    int256 pnlE30 = _getGlobalPNLE30();
    uint256 aum = _getPLPValueE30(_isMaxPrice) + pendingBorrowingFeeE30;

    if (pnlE30 < 0) {
      aum += uint256(-pnlE30);
    } else {
      uint256 _pnl = uint256(pnlE30);
      if (aum < _pnl) return 0;
      unchecked {
        aum -= _pnl;
      }
    }

    return aum;
  }

  /// @notice getPendingBorrowingFeeE30 This function calculates the total pending borrowing fee from all asset classes.
  /// @return total pending borrowing fee in e30 format
  function getPendingBorrowingFeeE30() external view returns (uint256) {
    return _getPendingBorrowingFeeE30();
  }

  /// @notice _getPendingBorrowingFeeE30 This function calculates the total pending borrowing fee from all asset classes.
  /// @return total pending borrowing fee in e30 format
  function _getPendingBorrowingFeeE30() internal view returns (uint256) {
    // SLOAD
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    uint256 _len = ConfigStorage(configStorage).getAssetClassConfigsLength();

    // Get the PLP TVL.
    uint256 _plpTVL = _getPLPValueE30(false);
    uint256 _pendingBorrowingFee; // sum from each asset class
    for (uint256 i; i < _len; ) {
      PerpStorage.GlobalAssetClass memory _assetClassState = _perpStorage.getGlobalAssetClassByIndex(i);

      uint256 _borrowingFeeE30 = (_getNextBorrowingRate(uint8(i), _plpTVL) * _assetClassState.reserveValueE30) /
        RATE_PRECISION;

      // Formula:
      // pendingBorrowingFee = (sumBorrowingFeeE30 - sumSettledBorrowingFeeE30) + latestBorrowingFee
      _pendingBorrowingFee +=
        (_assetClassState.sumBorrowingFeeE30 - _assetClassState.sumSettledBorrowingFeeE30) +
        _borrowingFeeE30;

      unchecked {
        ++i;
      }
    }

    return _pendingBorrowingFee;
  }

  /// @notice GetPLPValue in E30
  /// @param _isMaxPrice Use Max or Min Price
  /// @return PLP Value
  function getPLPValueE30(bool _isMaxPrice) external view returns (uint256) {
    return _getPLPValueE30(_isMaxPrice);
  }

  /// @notice GetPLPValue in E30
  /// @param _isMaxPrice Use Max or Min Price
  /// @return PLP Value
  function _getPLPValueE30(bool _isMaxPrice) internal view returns (uint256) {
    ConfigStorage _configStorage = ConfigStorage(configStorage);

    bytes32[] memory _plpAssetIds = _configStorage.getPlpAssetIds();
    uint256 assetValue = 0;
    uint256 _len = _plpAssetIds.length;

    for (uint256 i = 0; i < _len; ) {
      uint256 value = _getPLPUnderlyingAssetValueE30(_plpAssetIds[i], _configStorage, _isMaxPrice);
      unchecked {
        assetValue += value;
        ++i;
      }
    }

    return assetValue;
  }

  /// @notice Get PLP underlying asset value in E30
  /// @param _underlyingAssetId the underlying asset id, the one we want to find the value
  /// @param _configStorage config storage
  /// @param _isMaxPrice Use Max or Min Price
  /// @return PLP Value
  function _getPLPUnderlyingAssetValueE30(
    bytes32 _underlyingAssetId,
    ConfigStorage _configStorage,
    bool _isMaxPrice
  ) internal view returns (uint256) {
    ConfigStorage.AssetConfig memory _assetConfig = _configStorage.getAssetConfig(_underlyingAssetId);

    (uint256 _priceE30, , ) = OracleMiddleware(oracle).unsafeGetLatestPrice(_underlyingAssetId, _isMaxPrice);
    uint256 value = (VaultStorage(vaultStorage).plpLiquidity(_assetConfig.tokenAddress) * _priceE30) /
      (10 ** _assetConfig.decimals);

    return value;
  }

  /// @notice getPLPPrice in e18 format
  /// @param _aum aum in PLP
  /// @param _plpSupply Total Supply of PLP token
  /// @return PLP Price in e18
  function getPLPPrice(uint256 _aum, uint256 _plpSupply) external pure returns (uint256) {
    if (_plpSupply == 0) return 0;
    return _aum / _plpSupply;
  }

  /// @notice get all PNL in e30 format
  /// @return pnl value
  function _getGlobalPNLE30() internal view returns (int256) {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    OracleMiddleware _oracle = OracleMiddleware(oracle);

    int256 totalPnlLong = 0;
    int256 totalPnlShort = 0;
    uint256 _len = _configStorage.getMarketConfigsLength();

    for (uint256 i = 0; i < _len; ) {
      ConfigStorage.MarketConfig memory _marketConfig = _configStorage.getMarketConfigByIndex(i);
      PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(i);

      int256 _pnlLongE30 = 0;
      int256 _pnlShortE30 = 0;
      (uint256 priceE30, , ) = _oracle.unsafeGetLatestPrice(_marketConfig.assetId, false);

      if (_globalMarket.longAvgPrice > 0 && _globalMarket.longPositionSize > 0) {
        if (priceE30 < _globalMarket.longAvgPrice) {
          uint256 _absPNL = ((_globalMarket.longAvgPrice - priceE30) * _globalMarket.longPositionSize) /
            _globalMarket.longAvgPrice;
          _pnlLongE30 = -int256(_absPNL);
        } else {
          uint256 _absPNL = ((priceE30 - _globalMarket.longAvgPrice) * _globalMarket.longPositionSize) /
            _globalMarket.longAvgPrice;
          _pnlLongE30 = int256(_absPNL);
        }
      }

      if (_globalMarket.shortAvgPrice > 0 && _globalMarket.shortPositionSize > 0) {
        if (_globalMarket.shortAvgPrice < priceE30) {
          uint256 _absPNL = ((priceE30 - _globalMarket.shortAvgPrice) * _globalMarket.shortPositionSize) /
            _globalMarket.shortAvgPrice;

          _pnlShortE30 = -int256(_absPNL);
        } else {
          uint256 _absPNL = ((_globalMarket.shortAvgPrice - priceE30) * _globalMarket.shortPositionSize) /
            _globalMarket.shortAvgPrice;
          _pnlShortE30 = int256(_absPNL);
        }
      }

      {
        unchecked {
          ++i;
          totalPnlLong += _pnlLongE30;
          totalPnlShort += _pnlShortE30;
        }
      }
    }

    return totalPnlLong + totalPnlShort;
  }

  /// @notice getMintAmount in e18 format
  /// @param _aumE30 aum in PLP E30
  /// @param _totalSupply PLP total supply
  /// @param _value value in USD e30
  /// @return mintAmount in e18 format
  function getMintAmount(uint256 _aumE30, uint256 _totalSupply, uint256 _value) external pure returns (uint256) {
    return _aumE30 == 0 ? _value / 1e12 : (_value * _totalSupply) / _aumE30;
  }

  function convertTokenDecimals(
    uint256 fromTokenDecimals,
    uint256 toTokenDecimals,
    uint256 amount
  ) external pure returns (uint256) {
    return (amount * 10 ** toTokenDecimals) / 10 ** fromTokenDecimals;
  }

  function getAddLiquidityFeeBPS(
    address _token,
    uint256 _tokenValueE30,
    ConfigStorage _configStorage
  ) external view returns (uint32) {
    if (!_configStorage.getLiquidityConfig().dynamicFeeEnabled) {
      return _configStorage.getLiquidityConfig().depositFeeRateBPS;
    }

    return
      _getFeeBPS(
        _tokenValueE30,
        _getPLPUnderlyingAssetValueE30(_configStorage.tokenAssetIds(_token), _configStorage, false),
        _getPLPValueE30(false),
        _configStorage.getLiquidityConfig(),
        _configStorage.getAssetPlpTokenConfigByToken(_token),
        LiquidityDirection.ADD
      );
  }

  function getRemoveLiquidityFeeBPS(
    address _token,
    uint256 _tokenValueE30,
    ConfigStorage _configStorage
  ) external view returns (uint32) {
    if (!_configStorage.getLiquidityConfig().dynamicFeeEnabled) {
      return _configStorage.getLiquidityConfig().withdrawFeeRateBPS;
    }

    return
      _getFeeBPS(
        _tokenValueE30,
        _getPLPUnderlyingAssetValueE30(_configStorage.tokenAssetIds(_token), _configStorage, true),
        _getPLPValueE30(true),
        _configStorage.getLiquidityConfig(),
        _configStorage.getAssetPlpTokenConfigByToken(_token),
        LiquidityDirection.REMOVE
      );
  }

  function _getFeeBPS(
    uint256 _value, //e30
    uint256 _liquidityUSD, //e30
    uint256 _totalLiquidityUSD, //e30
    ConfigStorage.LiquidityConfig memory _liquidityConfig,
    ConfigStorage.PLPTokenConfig memory _plpTokenConfig,
    LiquidityDirection direction
  ) internal pure returns (uint32) {
    uint32 _feeBPS = direction == LiquidityDirection.ADD
      ? _liquidityConfig.depositFeeRateBPS
      : _liquidityConfig.withdrawFeeRateBPS;
    uint32 _taxBPS = _liquidityConfig.taxFeeRateBPS;
    uint256 _totalTokenWeight = _liquidityConfig.plpTotalTokenWeight;

    uint256 startValue = _liquidityUSD;
    uint256 nextValue = startValue + _value;
    if (direction == LiquidityDirection.REMOVE) nextValue = _value > startValue ? 0 : startValue - _value;

    uint256 targetValue = _getTargetValue(_totalLiquidityUSD, _plpTokenConfig.targetWeight, _totalTokenWeight);

    if (targetValue == 0) return _feeBPS;

    uint256 startTargetDiff = startValue > targetValue ? startValue - targetValue : targetValue - startValue;
    uint256 nextTargetDiff = nextValue > targetValue ? nextValue - targetValue : targetValue - nextValue;

    // nextValue moves closer to the targetValue -> positive case;
    // Should apply rebate.
    if (nextTargetDiff < startTargetDiff) {
      uint32 rebateBPS = uint32((_taxBPS * startTargetDiff) / targetValue);
      return rebateBPS > _feeBPS ? 0 : _feeBPS - rebateBPS;
    }

    // _nextWeight represented 18 precision
    uint256 _nextWeight = (nextValue * ETH_PRECISION) / (_totalLiquidityUSD + _value);
    if (_nextWeight > _plpTokenConfig.targetWeight + _plpTokenConfig.maxWeightDiff) {
      revert ICalculator_PoolImbalance();
    }

    // If not then -> negative impact to the pool.
    // Should apply tax.
    uint256 midDiff = (startTargetDiff + nextTargetDiff) / 2;
    if (midDiff > targetValue) {
      midDiff = targetValue;
    }
    _taxBPS = uint32((_taxBPS * midDiff) / targetValue);

    return uint32(_feeBPS + _taxBPS);
  }

  /// @notice get settlement fee rate
  /// @param _token - token
  /// @param _liquidityUsdDelta - withdrawal amount
  /// @return _settlementFeeRate in e18 format
  function getSettlementFeeRate(
    address _token,
    uint256 _liquidityUsdDelta
  ) external view returns (uint256 _settlementFeeRate) {
    // usd debt
    uint256 _tokenLiquidityUsd = _getPLPUnderlyingAssetValueE30(
      ConfigStorage(configStorage).tokenAssetIds(_token),
      ConfigStorage(configStorage),
      false
    );
    if (_tokenLiquidityUsd == 0) return 0;

    // total usd debt

    uint256 _totalLiquidityUsd = _getPLPValueE30(false);
    ConfigStorage.LiquidityConfig memory _liquidityConfig = ConfigStorage(configStorage).getLiquidityConfig();

    // target value = total usd debt * target weight ratio (targe weigh / total weight);

    uint256 _targetUsd = (_totalLiquidityUsd *
      ConfigStorage(configStorage).getAssetPlpTokenConfigByToken(_token).targetWeight) /
      _liquidityConfig.plpTotalTokenWeight;

    if (_targetUsd == 0) return 0;

    // next value
    uint256 _nextUsd = _tokenLiquidityUsd - _liquidityUsdDelta;

    // current target diff
    uint256 _currentTargetDiff;
    uint256 _nextTargetDiff;
    unchecked {
      _currentTargetDiff = _tokenLiquidityUsd > _targetUsd
        ? _tokenLiquidityUsd - _targetUsd
        : _targetUsd - _tokenLiquidityUsd;
      // next target diff
      _nextTargetDiff = _nextUsd > _targetUsd ? _nextUsd - _targetUsd : _targetUsd - _nextUsd;
    }

    if (_nextTargetDiff < _currentTargetDiff) return 0;

    // settlement fee rate = (next target diff + current target diff / 2) * base tax fee / target usd
    return
      (((_nextTargetDiff + _currentTargetDiff) / 2) * _liquidityConfig.taxFeeRateBPS * ETH_PRECISION) /
      _targetUsd /
      BPS;
  }

  // return in e18
  function _getTargetValue(
    uint256 totalLiquidityUSD, //e30
    uint256 tokenWeight, //e18
    uint256 totalTokenWeight // 1e18
  ) internal pure returns (uint256) {
    if (totalLiquidityUSD == 0) return 0;

    return (totalLiquidityUSD * tokenWeight) / totalTokenWeight;
  }

  /**
   * Setter functions
   */

  /// @notice Set new Oracle contract address.
  /// @param _oracle New Oracle contract address.
  function setOracle(address _oracle) external onlyOwner {
    // @todo - Sanity check
    if (_oracle == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetOracle(oracle, _oracle);
    oracle = _oracle;
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external onlyOwner {
    // @todo - Sanity check
    if (_vaultStorage == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;
  }

  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external onlyOwner {
    // @todo - Sanity check
    if (_configStorage == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external onlyOwner {
    // @todo - Sanity check
    if (_perpStorage == address(0)) revert ICalculator_InvalidAddress();
    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  ////////////////////// CALCULATOR
  ////////////////////////////////////////////////////////////////////////////////////

  /// @notice Calculate for value on trader's account including Equity, IMR and MMR.
  /// @dev Equity = Sum(collateral tokens' Values) + Sum(unrealized PnL) - Unrealized Borrowing Fee - Unrealized Funding Fee
  /// @param _subAccount Trader account's address.
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  /// @return _equityValueE30 Total equity of trader's account.
  function getEquity(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) external view returns (int256 _equityValueE30) {
    return _getEquity(_subAccount, _limitPriceE30, _limitAssetId);
  }

  function _getEquity(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) internal view returns (int256 _equityValueE30) {
    // Calculate collateral tokens' value on trader's sub account
    uint256 _collateralValueE30 = _getCollateralValue(_subAccount, _limitPriceE30, _limitAssetId);

    // Calculate unrealized PnL and unrealized fee
    (int256 _unrealizedPnlValueE30, int256 _unrealizedFeeValueE30) = _getUnrealizedPnlAndFee(
      _subAccount,
      _limitPriceE30,
      _limitAssetId
    );

    // Calculate equity
    _equityValueE30 += int256(_collateralValueE30);
    _equityValueE30 += _unrealizedPnlValueE30;
    _equityValueE30 -= _unrealizedFeeValueE30;

    return _equityValueE30;
  }

  struct GetUnrealizedPnlAndFee {
    PerpStorage.Position position;
    uint256 absSize;
    bool isLong;
    uint256 priceE30;
    bool isProfit;
    uint256 delta;
  }

  // @todo integrate realizedPnl Value

  /// @notice Calculate unrealized PnL from trader's sub account.
  /// @dev This unrealized pnl deducted by collateral factor.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  /// @return _unrealizedPnlE30 PnL value after deducted by collateral factor.
  function getUnrealizedPnlAndFee(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) external view returns (int256 _unrealizedPnlE30, int256 _unrealizedFeeE30) {
    return _getUnrealizedPnlAndFee(_subAccount, _limitPriceE30, _limitAssetId);
  }

  function _getUnrealizedPnlAndFee(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) internal view returns (int256 _unrealizedPnlE30, int256 _unrealizedFeeE30) {
    // Get all trader's opening positions
    PerpStorage.Position[] memory _positions = PerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    ConfigStorage.MarketConfig memory _marketConfig;
    PerpStorage.GlobalMarket memory _globalMarket;
    uint256 pnlFactorBps = ConfigStorage(configStorage).pnlFactorBPS();
    uint256 liquidationFee = ConfigStorage(configStorage).getLiquidationConfig().liquidationFeeUSDE30;

    GetUnrealizedPnlAndFee memory _var;
    uint256 _len = _positions.length;

    // Loop through all trader's positions
    for (uint256 i; i < _len; ) {
      _var.position = _positions[i];
      _var.absSize = _abs(_var.position.positionSizeE30);
      _var.isLong = _var.position.positionSizeE30 > 0;

      // Get market config according to opening position
      _marketConfig = ConfigStorage(configStorage).getMarketConfigByIndex(_var.position.marketIndex);
      _globalMarket = PerpStorage(perpStorage).getGlobalMarketByIndex(_var.position.marketIndex);

      // Check to overwrite price
      if (_limitAssetId == _marketConfig.assetId && _limitPriceE30 != 0) {
        _var.priceE30 = _limitPriceE30;
      } else {
        // @todo - validate price age
        (_var.priceE30, , , ) = OracleMiddleware(oracle).getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          !_var.isLong, // if current position is SHORT position, then we use max price
          (int(_globalMarket.longPositionSize) - int(_globalMarket.shortPositionSize)),
          -_var.position.positionSizeE30,
          _marketConfig.fundingRate.maxSkewScaleUSD,
          0
        );
      }

      {
        // Calculate pnl
        (_var.isProfit, _var.delta) = _getDelta(
          _var.absSize,
          _var.isLong,
          _var.priceE30,
          _var.position.avgEntryPriceE30,
          _var.position.lastIncreaseTimestamp
        );
        if (_var.isProfit) {
          _unrealizedPnlE30 += int256((pnlFactorBps * _var.delta) / BPS);
        } else {
          _unrealizedPnlE30 -= int256(_var.delta);
        }
      }

      {
        {
          // Calculate borrowing fee
          uint256 _plpTVL = _getPLPValueE30(false);
          PerpStorage.GlobalAssetClass memory _globalAssetClass = PerpStorage(perpStorage).getGlobalAssetClassByIndex(
            _marketConfig.assetClass
          );
          uint256 _nextBorrowingRate = _getNextBorrowingRate(_marketConfig.assetClass, _plpTVL);
          _unrealizedFeeE30 += int256(
            _getBorrowingFee(
              _var.position.reserveValueE30,
              _globalAssetClass.sumBorrowingRate + _nextBorrowingRate,
              _var.position.entryBorrowingRate
            )
          );
        }
        {
          // Calculate funding fee
          int256 nextFundingRate = _getNextFundingRate(_var.position.marketIndex);
          int256 fundingRate = _globalMarket.currentFundingRate + nextFundingRate;
          _unrealizedFeeE30 += _getFundingFee(_var.isLong, _var.absSize, fundingRate, _var.position.entryFundingRate);
        }
        // Calculate trading fee
        _unrealizedFeeE30 += int256(_getTradingFee(_var.absSize, _marketConfig.decreasePositionFeeRateBPS));
      }

      unchecked {
        ++i;
      }
    }

    if (_len != 0) {
      // Calculate liquidation fee
      _unrealizedFeeE30 += int256(liquidationFee);
    }

    return (_unrealizedPnlE30, _unrealizedFeeE30);
  }

  /// @notice Calculate collateral tokens to value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  /// @return _collateralValueE30
  function getCollateralValue(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) external view returns (uint256 _collateralValueE30) {
    return _getCollateralValue(_subAccount, _limitPriceE30, _limitAssetId);
  }

  function _getCollateralValue(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) internal view returns (uint256 _collateralValueE30) {
    // Get list of current depositing tokens on trader's account
    address[] memory _traderTokens = VaultStorage(vaultStorage).getTraderTokens(_subAccount);

    // Loop through list of current depositing tokens
    for (uint256 i; i < _traderTokens.length; ) {
      address _token = _traderTokens[i];
      ConfigStorage.CollateralTokenConfig memory _collateralTokenConfig = ConfigStorage(configStorage)
        .getCollateralTokenConfigs(_token);

      // Get token decimals from ConfigStorage
      uint256 _decimals = ConfigStorage(configStorage).getAssetConfigByToken(_token).decimals;

      // Get collateralFactor from ConfigStorage
      uint32 collateralFactorBPS = _collateralTokenConfig.collateralFactorBPS;

      // Get current collateral token balance of trader's account
      uint256 _amount = VaultStorage(vaultStorage).traderBalances(_subAccount, _token);

      // Get price from oracle
      uint256 _priceE30;

      // Get token asset id from ConfigStorage
      bytes32 _tokenAssetId = ConfigStorage(configStorage).tokenAssetIds(_token);
      if (_tokenAssetId == _limitAssetId && _limitPriceE30 != 0) {
        _priceE30 = _limitPriceE30;
      } else {
        // @todo - validate price age
        (_priceE30, , ) = OracleMiddleware(oracle).getLatestPriceWithMarketStatus(
          _tokenAssetId,
          false // @note Collateral value always use Min price
        );
      }
      // Calculate accumulative value of collateral tokens
      // collateral value = (collateral amount * price) * collateralFactorBPS
      // collateralFactor 1e4 = 100%
      _collateralValueE30 += (_amount * _priceE30 * collateralFactorBPS) / ((10 ** _decimals) * BPS);

      unchecked {
        i++;
      }
    }

    return _collateralValueE30;
  }

  /// @notice Calculate Initial Margin Requirement from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _imrValueE30 Total imr of trader's account.
  function getIMR(address _subAccount) external view returns (uint256 _imrValueE30) {
    return _getIMR(_subAccount);
  }

  function _getIMR(address _subAccount) internal view returns (uint256 _imrValueE30) {
    // Get all trader's opening positions
    PerpStorage.Position[] memory _traderPositions = PerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      PerpStorage.Position memory _position = _traderPositions[i];

      uint256 _size;
      if (_position.positionSizeE30 < 0) {
        _size = uint(_position.positionSizeE30 * -1);
      } else {
        _size = uint(_position.positionSizeE30);
      }

      // Calculate IMR on position
      _imrValueE30 += _calculatePositionIMR(_size, _position.marketIndex);

      unchecked {
        i++;
      }
    }

    return _imrValueE30;
  }

  /// @notice Calculate Maintenance Margin Value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _mmrValueE30 Total mmr of trader's account
  function getMMR(address _subAccount) external view returns (uint256 _mmrValueE30) {
    return _getMMR(_subAccount);
  }

  function _getMMR(address _subAccount) internal view returns (uint256 _mmrValueE30) {
    // Get all trader's opening positions
    PerpStorage.Position[] memory _traderPositions = PerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      PerpStorage.Position memory _position = _traderPositions[i];

      uint256 _size;
      if (_position.positionSizeE30 < 0) {
        _size = uint(_position.positionSizeE30 * -1);
      } else {
        _size = uint(_position.positionSizeE30);
      }

      // Calculate MMR on position
      _mmrValueE30 += _calculatePositionMMR(_size, _position.marketIndex);

      unchecked {
        i++;
      }
    }

    return _mmrValueE30;
  }

  /// @notice Calculate for Initial Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _imrE30 The IMR amount required on position size, 30 decimals.
  function calculatePositionIMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) external view returns (uint256 _imrE30) {
    return _calculatePositionIMR(_positionSizeE30, _marketIndex);
  }

  function _calculatePositionIMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) internal view returns (uint256 _imrE30) {
    // Get market config according to position
    ConfigStorage.MarketConfig memory _marketConfig = ConfigStorage(configStorage).getMarketConfigByIndex(_marketIndex);

    _imrE30 = (_positionSizeE30 * _marketConfig.initialMarginFractionBPS) / BPS;
    return _imrE30;
  }

  /// @notice Calculate for Maintenance Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _mmrE30 The MMR amount required on position size, 30 decimals.
  function calculatePositionMMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) external view returns (uint256 _mmrE30) {
    return _calculatePositionMMR(_positionSizeE30, _marketIndex);
  }

  function _calculatePositionMMR(
    uint256 _positionSizeE30,
    uint256 _marketIndex
  ) internal view returns (uint256 _mmrE30) {
    // Get market config according to position
    ConfigStorage.MarketConfig memory _marketConfig = ConfigStorage(configStorage).getMarketConfigByIndex(_marketIndex);

    _mmrE30 = (_positionSizeE30 * _marketConfig.maintenanceMarginFractionBPS) / BPS;
    return _mmrE30;
  }

  /// @notice This function returns the amount of free collateral available to a given sub-account
  /// @param _subAccount The address of the sub-account
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  /// @return _freeCollateral The amount of free collateral available to the sub-account
  function getFreeCollateral(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) external view returns (uint256 _freeCollateral) {
    return _getFreeCollateral(_subAccount, _limitPriceE30, _limitAssetId);
  }

  function _getFreeCollateral(
    address _subAccount,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) internal view returns (uint256 _freeCollateral) {
    int256 equity = _getEquity(_subAccount, _limitPriceE30, _limitAssetId);
    uint256 imr = _getIMR(_subAccount);
    if (equity < int256(imr)) return 0;
    _freeCollateral = uint256(equity) - imr;
    return _freeCollateral;
  }

  /// @notice Calculate next market average price
  /// @param _marketPositionSize - market's (long | short) position size
  /// @param _marketAveragePrice - market's average price
  /// @param _sizeDelta - position's size delta
  //                    - increase (long +, short -)
  //                    - decrease (long -, short +)
  /// @param _positionClosePrice - position's close price
  /// @param _positionRealizedPnl - position's realized PNL (profit +, loss -)
  function calculateMarketAveragePrice(
    int256 _marketPositionSize,
    uint256 _marketAveragePrice,
    int256 _sizeDelta,
    uint256 _positionClosePrice,
    int256 _positionRealizedPnl
  ) external pure returns (uint256 _newAvaragePrice) {
    if (_marketAveragePrice == 0) return 0;
    // pnl calculation, LONG  -- position size * ((close price - average price) / average price)
    //                  SHORT -- position size * ((average price - close price) / average price)
    // example:
    // LONG  -- 1000 * ((105 - 100) / 100) = 50 (profit)
    //       -- 1000 * ((95 - 100) / 100) = -50 (loss)
    // SHORT -- -1000 * ((100 - 95) / 100) = -50 (profit)
    //       -- -1000 * ((100 - 105) / 100) = 50 (loss)
    bool isLong = _marketPositionSize > 0;
    int256 _marketPnl;
    if (isLong) {
      _marketPnl =
        (_marketPositionSize * (int256(_positionClosePrice) - int256(_marketAveragePrice))) /
        int256(_marketAveragePrice);
    } else {
      _marketPnl =
        (_marketPositionSize * (int256(_marketAveragePrice) - int256(_positionClosePrice))) /
        int256(_marketAveragePrice);
    }

    // unrealized pnl = market pnl - position realized pnl
    // example:
    // LONG  -- market pnl = 100,   realized position pnl = 50    then market unrealized pnl = 100 - 50     = 50  [profit]
    //       -- market pnl = -100,  realized position pnl = -50   then market unrealized pnl = -100 - (-50) = -50 [loss]

    // SHORT -- market pnl = -100,  realized position pnl = -50   then market unrealized pnl = -100 - (-50) = -50 [profit]
    //       -- market pnl = 100,   realized position pnl = 50    then market unrealized pnl = 100 - 50     = 50  [loss]
    int256 _unrealizedPnl = _marketPnl - _positionRealizedPnl;

    // | action         | market position | size delta |
    // | increase long  | +               | +          |
    // | decrease long  | +               | -          |
    // | increase short | -               | -          |
    // | decrease short | -               | +          |
    // then _marketPositionSize + _sizeDelta will work fine
    int256 _newMarketPositionSize = _marketPositionSize + _sizeDelta;
    int256 _divisor = isLong ? _newMarketPositionSize + _unrealizedPnl : _newMarketPositionSize - _unrealizedPnl;

    if (_newMarketPositionSize == 0) return 0;

    // for long, new market position size and divisor are positive number
    // and short, new market position size and divisor are negative number, then - / - would be +
    // note: abs unrealized pnl should not be greater then new position size, if calculation go wrong it's fine to revert
    return uint256((int256(_positionClosePrice) * _newMarketPositionSize) / _divisor);
  }

  function getNextFundingRate(uint256 _marketIndex) external view returns (int256 fundingRate) {
    return _getNextFundingRate(_marketIndex);
  }

  /// @notice Calculate next funding rate using when increase/decrease position.
  /// @param _marketIndex Market Index.
  /// @return fundingRate next funding rate using for both LONG & SHORT positions.
  function _getNextFundingRate(uint256 _marketIndex) internal view returns (int256 fundingRate) {
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    GetFundingRateVar memory vars;
    ConfigStorage.MarketConfig memory marketConfig = _configStorage.getMarketConfigByIndex(_marketIndex);
    PerpStorage.GlobalMarket memory globalMarket = PerpStorage(perpStorage).getGlobalMarketByIndex(_marketIndex);
    if (marketConfig.fundingRate.maxFundingRate == 0 || marketConfig.fundingRate.maxSkewScaleUSD == 0) return 0;
    // Get funding interval
    vars.fundingInterval = _configStorage.getTradingConfig().fundingInterval;
    // If block.timestamp not pass the next funding time, return 0.
    if (globalMarket.lastFundingTime + vars.fundingInterval > block.timestamp) return 0;

    vars.marketSkewUSDE30 = int(globalMarket.longPositionSize) - int(globalMarket.shortPositionSize);

    // The result of this nextFundingRate Formula will be in the range of [-maxFundingRate, maxFundingRate]
    vars.ratio = _max(-1e18, -((vars.marketSkewUSDE30 * 1e18) / int(marketConfig.fundingRate.maxSkewScaleUSD)));
    vars.ratio = _min(vars.ratio, 1e18);
    vars.nextFundingRate = (vars.ratio * int(uint(marketConfig.fundingRate.maxFundingRate))) / 1e18;

    vars.elapsedIntervals = int((block.timestamp - globalMarket.lastFundingTime) / vars.fundingInterval);
    vars.nextFundingRate = vars.nextFundingRate * vars.elapsedIntervals;

    return vars.nextFundingRate;
  }

  /**
   * Funding Rate
   */
  /// @notice This function returns funding fee according to trader's position
  /// @param _marketIndex Index of market
  /// @param _isLong Is long or short exposure
  /// @param _size Position size
  /// @return fundingFee Funding fee of position
  function getFundingFee(
    uint256 _marketIndex,
    bool _isLong,
    int256 _size,
    int256 _entryFundingRate
  ) external view returns (int256 fundingFee) {
    if (_size == 0) return 0;
    uint256 absSize = _size > 0 ? uint(_size) : uint(-_size);

    PerpStorage.GlobalMarket memory _globalMarket = PerpStorage(perpStorage).getGlobalMarketByIndex(_marketIndex);

    return _getFundingFee(_isLong, absSize, _globalMarket.currentFundingRate, _entryFundingRate);
  }

  function _getFundingFee(
    bool _isLong,
    uint256 _size,
    int256 _sumFundingRate,
    int256 _entryFundingRate
  ) private pure returns (int256 fundingFee) {
    int256 _fundingRate = _sumFundingRate - _entryFundingRate;

    // IF _fundingRate < 0, LONG positions pay fees to SHORT and SHORT positions receive fees from LONG
    // IF _fundingRate > 0, LONG positions receive fees from SHORT and SHORT pay fees to LONG
    fundingFee = (int256(_size) * _fundingRate) / int64(RATE_PRECISION);

    // Position Exposure   | Funding Rate       | Fund Flow
    // (isLong)            | (fundingRate > 0)  | (traderMustPay)
    // ---------------------------------------------------------------------
    // true                | true               | false  (fee reserve -> trader)
    // true                | false              | true   (trader -> fee reserve)
    // false               | true               | true   (trader -> fee reserve)
    // false               | false              | false  (fee reserve -> trader)

    // If fundingFee is negative mean Trader receives Fee
    // If fundingFee is positive mean Trader pays Fee
    if (_isLong) {
      return -fundingFee;
    }
    return fundingFee;
  }

  /// @notice Calculates the borrowing fee for a given asset class based on the reserved value, entry borrowing rate, and current sum borrowing rate of the asset class.
  /// @param _assetClassIndex The index of the asset class for which to calculate the borrowing fee.
  /// @param _reservedValue The reserved value of the asset class.
  /// @param _entryBorrowingRate The entry borrowing rate of the asset class.
  /// @return borrowingFee The calculated borrowing fee for the asset class.
  function getBorrowingFee(
    uint8 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _entryBorrowingRate
  ) external view returns (uint256 borrowingFee) {
    // Get the global asset class.
    PerpStorage.GlobalAssetClass memory _assetClassState = PerpStorage(perpStorage).getGlobalAssetClassByIndex(
      _assetClassIndex
    );
    // // Calculate borrowing fee.
    return _getBorrowingFee(_reservedValue, _assetClassState.sumBorrowingRate, _entryBorrowingRate);
  }

  function _getBorrowingFee(
    uint256 _reservedValue,
    uint256 _sumBorrowingRate,
    uint256 _entryBorrowingRate
  ) internal pure returns (uint256 borrowingFee) {
    // Calculate borrowing rate.
    uint256 _borrowingRate = _sumBorrowingRate - _entryBorrowingRate;
    // Calculate the borrowing fee based on reserved value, borrowing rate.
    return (_reservedValue * _borrowingRate) / RATE_PRECISION;
  }

  function getNextBorrowingRate(
    uint8 _assetClassIndex,
    uint256 _plpTVL
  ) external view returns (uint256 _nextBorrowingRate) {
    return _getNextBorrowingRate(_assetClassIndex, _plpTVL);
  }

  /// @notice This function takes an asset class index as input and returns the next borrowing rate for that asset class.
  /// @param _assetClassIndex The index of the asset class.
  /// @param _plpTVL value in plp
  /// @return _nextBorrowingRate The next borrowing rate for the asset class.
  function _getNextBorrowingRate(
    uint8 _assetClassIndex,
    uint256 _plpTVL
  ) internal view returns (uint256 _nextBorrowingRate) {
    ConfigStorage _configStorage = ConfigStorage(configStorage);

    // Get the trading config, asset class config, and global asset class for the given asset class index.
    ConfigStorage.TradingConfig memory _tradingConfig = _configStorage.getTradingConfig();
    ConfigStorage.AssetClassConfig memory _assetClassConfig = _configStorage.getAssetClassConfigByIndex(
      _assetClassIndex
    );
    PerpStorage.GlobalAssetClass memory _assetClassState = PerpStorage(perpStorage).getGlobalAssetClassByIndex(
      _assetClassIndex
    );
    // If block.timestamp not pass the next funding time, return 0.
    if (_assetClassState.lastBorrowingTime + _tradingConfig.fundingInterval > block.timestamp) return 0;

    // If PLP TVL is 0, return 0.
    if (_plpTVL == 0) return 0;

    // Calculate the number of funding intervals that have passed since the last borrowing time.
    uint256 intervals = (block.timestamp - _assetClassState.lastBorrowingTime) / _tradingConfig.fundingInterval;

    // Calculate the next borrowing rate based on the asset class config, global asset class reserve value, and intervals.
    return (_assetClassConfig.baseBorrowingRate * _assetClassState.reserveValueE30 * intervals) / _plpTVL;
  }

  function getTradingFee(uint256 _size, uint256 _baseFeeRateBPS) external pure returns (uint256 tradingFee) {
    return _getTradingFee(_size, _baseFeeRateBPS);
  }

  function _getTradingFee(uint256 _size, uint256 _baseFeeRateBPS) internal pure returns (uint256 tradingFee) {
    return (_size * _baseFeeRateBPS) / BPS;
  }

  function getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice,
    uint256 _lastIncreaseTimestamp
  ) external view returns (bool, uint256) {
    return _getDelta(_size, _isLong, _markPrice, _averagePrice, _lastIncreaseTimestamp);
  }

  // @todo - pass current price here
  /// @notice Calculates the delta between average price and mark price, based on the size of position and whether the position is profitable.
  /// @param _size The size of the position.
  /// @param _isLong position direction
  /// @param _markPrice current market price
  /// @param _averagePrice The average price of the position.
  /// @return isProfit A boolean value indicating whether the position is profitable or not.
  /// @return delta The Profit between the average price and the fixed price, adjusted for the size of the order.
  function _getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice,
    uint256 _lastIncreaseTimestamp
  ) internal view returns (bool, uint256) {
    // Check for invalid input: averagePrice cannot be zero.
    if (_averagePrice == 0) return (false, 0);

    // Calculate the difference between the average price and the fixed price.
    uint256 priceDelta;
    unchecked {
      priceDelta = _averagePrice > _markPrice ? _averagePrice - _markPrice : _markPrice - _averagePrice;
    }

    // Calculate the delta, adjusted for the size of the order.
    uint256 delta = (_size * priceDelta) / _averagePrice;

    // Determine if the position is profitable or not based on the averagePrice and the mark price.
    bool isProfit;
    if (_isLong) {
      isProfit = _markPrice > _averagePrice;
    } else {
      isProfit = _markPrice < _averagePrice;
    }

    // In case of profit, we need to check the current timestamp against minProfitDuration
    // in order to prevent front-run attack, or price manipulation.
    // Check `isProfit` first, to save SLOAD in loss case.
    if (isProfit) {
      IConfigStorage.TradingConfig memory _tradingConfig = ConfigStorage(configStorage).getTradingConfig();
      if (block.timestamp < _lastIncreaseTimestamp + _tradingConfig.minProfitDuration) {
        return (isProfit, 0);
      }
    }

    // Return the values of isProfit and delta.
    return (isProfit, delta);
  }

  function _max(int256 a, int256 b) internal pure returns (int256) {
    return a > b ? a : b;
  }

  function _min(int256 a, int256 b) internal pure returns (int256) {
    return a < b ? a : b;
  }

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
