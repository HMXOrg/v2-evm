// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

import { Owned } from "../base/Owned.sol";

// Interfaces
import { ICalculator } from "./interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";

contract Calculator is Owned, ICalculator {
  uint256 internal constant MAX_RATE = 1e18;

  // using libs for type
  using AddressUtils for address;

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
    // @todo - Sanity check
    if (
      _oracle == address(0) || _vaultStorage == address(0) || _perpStorage == address(0) || _configStorage == address(0)
    ) revert ICalculator_InvalidAddress();
    oracle = _oracle;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    perpStorage = _perpStorage;
  }

  // return in
  function getAUME30(bool isMaxPrice) public view returns (uint256) {
    // @todo -  pendingBorrowingFeeE30
    // plpAUM = value of all asset + pnlShort + pnlLong + pendingBorrowingFee
    uint256 pendingBorrowingFeeE30 = 0;
    int256 pnlE30 = _getGlobalPNLE30();

    uint256 aum = _getPLPValueE30(isMaxPrice) + pendingBorrowingFeeE30;
    if (pnlE30 < 0) {
      uint256 _pnl = uint256(-pnlE30);
      if (aum < _pnl) return 0;
      aum -= _pnl;
    } else {
      aum += uint256(pnlE30);
    }

    return aum;
  }

  function getAUM(bool isMaxPrice) public view returns (uint256) {
    return getAUME30(isMaxPrice) / 1e12;
  }

  function getPLPValueE30(bool isMaxPrice) external view returns (uint256) {
    return _getPLPValueE30(isMaxPrice);
  }

  function _getPLPValueE30(bool isMaxPrice) internal view returns (uint256) {
    uint256 assetValue = 0;
    address _plpUnderlyingToken = IConfigStorage(configStorage).getNextAcceptedToken(
      IConfigStorage(configStorage).ITERABLE_ADDRESS_LIST_START()
    );

    while (
      _plpUnderlyingToken !=
      IConfigStorage(configStorage).getNextAcceptedToken(IConfigStorage(configStorage).ITERABLE_ADDRESS_LIST_END())
    ) {
      (uint256 priceE30, ) = IOracleMiddleware(oracle).unsafeGetLatestPrice(
        _plpUnderlyingToken.toBytes32(),
        isMaxPrice,
        IConfigStorage(configStorage).getMarketConfigByToken(_plpUnderlyingToken).priceConfidentThreshold
      );

      uint256 value = (IVaultStorage(vaultStorage).plpLiquidity(_plpUnderlyingToken) * priceE30) /
        (10 ** ERC20(_plpUnderlyingToken).decimals());

      unchecked {
        assetValue += value;
      }
      _plpUnderlyingToken = IConfigStorage(configStorage).getNextAcceptedToken(_plpUnderlyingToken);
    }

    return assetValue;
  }

  function getPLPPrice(uint256 aum, uint256 plpSupply) public pure returns (uint256) {
    if (plpSupply == 0) return 0;
    return aum / plpSupply;
  }

  function _getGlobalPNLE30() internal view returns (int256) {
    // @todo - REFACTOR if someone dont want totalPnlLong and short.
    int256 totalPnlLong = 0;
    int256 totalPnlShort = 0;

    for (uint256 i = 0; i < IConfigStorage(configStorage).getMarketConfigsLength(); ) {
      IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(i);

      IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(i);

      int256 _pnlLongE30 = 0;
      int256 _pnlShortE30 = 0;

      //@todo - validate timestamp of these
      (uint256 priceE30Long, ) = IOracleMiddleware(oracle).unsafeGetLatestPrice(
        marketConfig.assetId,
        false,
        marketConfig.priceConfidentThreshold
      );

      (uint256 priceE30Short, ) = IOracleMiddleware(oracle).unsafeGetLatestPrice(
        marketConfig.assetId,
        true,
        marketConfig.priceConfidentThreshold
      );

      //@todo - validate price, revert when crypto price stale, stock use Lastprice

      if (_globalMarket.longAvgPrice > 0 && _globalMarket.longPositionSize > 0) {
        if (priceE30Long < _globalMarket.longAvgPrice) {
          uint256 _absPNL = ((_globalMarket.longAvgPrice - priceE30Long) * _globalMarket.longPositionSize) /
            _globalMarket.longAvgPrice;
          _pnlLongE30 = -int256(_absPNL);
        } else {
          uint256 _absPNL = ((priceE30Long - _globalMarket.longAvgPrice) * _globalMarket.longPositionSize) /
            _globalMarket.longAvgPrice;
          _pnlLongE30 = int256(_absPNL);
        }
      }

      // @todo - DOUBLE CHECK :: ask team globalMarket.shortPositionSize store in negative???
      if (_globalMarket.shortAvgPrice > 0 && _globalMarket.shortPositionSize > 0) {
        if (_globalMarket.shortAvgPrice < priceE30Short) {
          uint256 _absPNL = ((priceE30Short - _globalMarket.shortAvgPrice) * _globalMarket.shortPositionSize) /
            _globalMarket.shortAvgPrice;

          _pnlShortE30 = -int256(_absPNL);
        } else {
          uint256 _absPNL = ((_globalMarket.shortAvgPrice - priceE30Short) * _globalMarket.shortPositionSize) /
            _globalMarket.shortAvgPrice;
          _pnlShortE30 = int256(_absPNL);
        }
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

  // @todo add more description
  // return in 1e18
  function getMintAmount(uint256 _aum, uint256 _totalSupply, uint256 _value) public pure returns (uint256) {
    return _aum == 0 ? _value / 1e12 : (_value * _totalSupply) / _aum / 1e12;
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
    if (direction == LiquidityDirection.REMOVE) nextValue = _value > startValue ? 0 : startValue - _value;

    uint256 targetValue = _getTargetValue(_totalLiquidityUSD, _plpTokenConfig.targetWeight, _totalTokenWeight);
    if (targetValue == 0) return _feeRate;

    uint256 startTargetDiff = startValue > targetValue ? startValue - targetValue : targetValue - startValue;

    uint256 nextTargetDiff = nextValue > targetValue ? nextValue - targetValue : targetValue - nextValue;

    // nextValue moves closer to the targetValue -> positive case;
    // Should apply rebate.
    if (nextTargetDiff < startTargetDiff) {
      uint256 rebateRate = (_taxRate * startTargetDiff) / targetValue;
      return rebateRate > _feeRate ? 0 : _feeRate - rebateRate;
    }

    // @todo - move this to service
    uint256 _nextWeight = (nextValue * 1e18) / targetValue;
    // if weight exceed targetWeight(e18) + maxWeight(e18)
    if (_nextWeight > _plpTokenConfig.targetWeight + _plpTokenConfig.maxWeightDiff) {
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

  /// @notice get settlement fee rate
  /// @param _token - token
  /// @param _liquidityUsdDelta - withdrawal amount
  function getSettlementFeeRate(
    address _token,
    uint256 _liquidityUsdDelta
  ) external returns (uint256 _settlementFeeRate) {
    // usd debt
    uint256 _tokenLiquidityUsd = IVaultStorage(vaultStorage).plpLiquidityUSDE30(_token);
    if (_tokenLiquidityUsd == 0) return 0;

    // total usd debt
    uint256 _totalLiquidityUsd = IVaultStorage(vaultStorage).plpTotalLiquidityUSDE30();

    IConfigStorage.LiquidityConfig memory _liquidityConfig = IConfigStorage(configStorage).getLiquidityConfig();

    // target value = total usd debt * target weight ratio (targe weigh / total weight);
    uint256 _targetUsd = (_totalLiquidityUsd * IConfigStorage(configStorage).getPLPTokenConfig(_token).targetWeight) /
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
    return (((_nextTargetDiff + _currentTargetDiff) / 2) * _liquidityConfig.taxFeeRate) / _targetUsd;
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

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTERs  ///////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

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
  /// @param _price Price from either limitOrder or Pyth
  /// @return _equityValueE30 Total equity of trader's account.
  function getEquity(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) public view returns (uint256 _equityValueE30) {
    // Calculate collateral tokens' value on trader's sub account
    //@todo guarantee limit order, getCollateralValue:: we do not know which price should be overriden, skip this part
    uint256 _collateralValueE30 = getCollateralValue(_subAccount, _price, _assetId);

    // Calculate unrealized PnL on opening trader's position(s)
    int256 _unrealizedPnlValueE30 = getUnrealizedPnl(_subAccount, _price, _assetId);

    // Calculate Borrwing fee on opening trader's position(s)
    // @todo - calculate borrowing fee
    // uint256 borrowingFeeE30 = getBorrowingFee(_subAccount);

    // @todo - calculate funding fee
    // uint256 fundingFeeE30 = getFundingFee(_subAccount);

    // Sum all asset's values
    _equityValueE30 += _collateralValueE30;

    if (_unrealizedPnlValueE30 > 0) {
      _equityValueE30 += uint256(_unrealizedPnlValueE30);
    } else {
      _equityValueE30 -= uint256(-_unrealizedPnlValueE30);
    }

    // @todo - include borrowing and funding fee
    // _equityValueE30 -= borrowingFeeE30;
    // _equityValueE30 -= fundingFeeE30;

    return _equityValueE30;
  }

  // @todo integrate realizedPnl Value

  /// @notice Calculate unrealized PnL from trader's sub account.
  /// @dev This unrealized pnl deducted by collateral factor.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _price Override price
  /// @param _assetId assetId indicates price should derived
  /// @return _unrealizedPnlE30 PnL value after deducted by collateral factor.
  function getUnrealizedPnl(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) public view returns (int256 _unrealizedPnlE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      IPerpStorage.Position memory _position = _traderPositions[i];
      bool _isLong = _position.positionSizeE30 > 0 ? true : false;

      if (_position.avgEntryPriceE30 == 0) revert ICalculator_InvalidAveragePrice();

      // Get market config according to opening position
      IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(
        _position.marketIndex
      );

      // Long position always use MinPrice. Short position always use MaxPrice
      bool _isUseMaxPrice = _isLong ? false : true;

      uint256 _priceE30;
      if (_assetId == _marketConfig.assetId && _price != 0) {
        _priceE30 = _price;
      } else {
        // Get price from oracle
        // @todo - validate price age
        (_priceE30, , ) = IOracleMiddleware(oracle).getLatestPriceWithMarketStatus(
          _marketConfig.assetId,
          _isUseMaxPrice,
          _marketConfig.priceConfidentThreshold,
          0
        );
      }
      // Calculate for priceDelta
      uint256 _priceDeltaE30;
      unchecked {
        _priceDeltaE30 = _position.avgEntryPriceE30 > _priceE30
          ? _position.avgEntryPriceE30 - _priceE30
          : _priceE30 - _position.avgEntryPriceE30;
      }

      int256 _delta = (_position.positionSizeE30 * int(_priceDeltaE30)) / int(_position.avgEntryPriceE30);

      if (_isLong) {
        _delta = _priceE30 > _position.avgEntryPriceE30 ? _delta : -_delta;
      } else {
        _delta = _priceE30 < _position.avgEntryPriceE30 ? -_delta : _delta;
      }

      // If profit then deduct PnL with colleral factor.
      _delta = _delta > 0 ? (int(IConfigStorage(configStorage).pnlFactor()) * _delta) / 1e18 : _delta;

      // Accumulative current unrealized PnL
      _unrealizedPnlE30 += _delta;

      unchecked {
        i++;
      }
    }

    return _unrealizedPnlE30;
  }

  /// @notice Calculate collateral tokens to value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _price Price from limitOrder, zeros means no marketOrderPrice,
  /// @param _assetId assetId to find token
  /// @return _collateralValueE30
  function getCollateralValue(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) public view returns (uint256 _collateralValueE30) {
    // Get list of current depositing tokens on trader's account
    address[] memory _traderTokens = IVaultStorage(vaultStorage).getTraderTokens(_subAccount);

    // Loop through list of current depositing tokens
    for (uint256 i; i < _traderTokens.length; ) {
      address _token = _traderTokens[i];

      // Get token decimals from ConfigStorage
      uint256 _decimals = ERC20(_token).decimals();

      // Get collateralFactor from ConfigStorage
      uint256 _collateralFactor = IConfigStorage(configStorage).getCollateralTokenConfigs(_token).collateralFactor;

      // Get priceConfidentThreshold from ConfigStorage
      uint256 _priceConfidenceThreshold = IConfigStorage(configStorage)
        .getMarketConfigByToken(_token)
        .priceConfidentThreshold;

      // Get current collateral token balance of trader's account
      uint256 _amount = IVaultStorage(vaultStorage).traderBalances(_subAccount, _token);

      // Get price from oracle
      uint256 _priceE30;

      if (_price != 0 && IOracleMiddleware(oracle).isSameAssetIdOnPyth(_token.toBytes32(), _assetId)) {
        _priceE30 = _price;
      } else {
        // @todo - validate price age
        (_priceE30, , ) = IOracleMiddleware(oracle).getLatestPriceWithMarketStatus(
          _token.toBytes32(),
          false, // @note Collateral value always use Min price
          _priceConfidenceThreshold,
          0
        );
      }
      // Calculate accumulative value of collateral tokens
      // collateal value = (collateral amount * price) * collateralFactor
      // collateralFactor 1 ether = 100%
      _collateralValueE30 += (_amount * _priceE30 * _collateralFactor) / (10 ** _decimals * 1e18);

      unchecked {
        i++;
      }
    }

    return _collateralValueE30;
  }

  /// @notice Calculate Intial Margin Requirement from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _imrValueE30 Total imr of trader's account.
  function getIMR(address _subAccount) public view returns (uint256 _imrValueE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      IPerpStorage.Position memory _position = _traderPositions[i];

      uint256 _size;
      if (_position.positionSizeE30 < 0) {
        _size = uint(_position.positionSizeE30 * -1);
      } else {
        _size = uint(_position.positionSizeE30);
      }

      // Calculate IMR on position
      _imrValueE30 += calculatePositionIMR(_size, _position.marketIndex);

      unchecked {
        i++;
      }
    }

    return _imrValueE30;
  }

  /// @notice Calculate Maintenance Margin Value from trader's sub account.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @return _mmrValueE30 Total mmr of trader's account
  function getMMR(address _subAccount) public view returns (uint256 _mmrValueE30) {
    // Get all trader's opening positions
    IPerpStorage.Position[] memory _traderPositions = IPerpStorage(perpStorage).getPositionBySubAccount(_subAccount);

    // Loop through all trader's positions
    for (uint256 i; i < _traderPositions.length; ) {
      IPerpStorage.Position memory _position = _traderPositions[i];

      uint256 _size;
      if (_position.positionSizeE30 < 0) {
        _size = uint(_position.positionSizeE30 * -1);
      } else {
        _size = uint(_position.positionSizeE30);
      }
      // Calculate MMR on position
      _mmrValueE30 += calculatePositionMMR(_size, _position.marketIndex);

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
  function calculatePositionIMR(uint256 _positionSizeE30, uint256 _marketIndex) public view returns (uint256 _imrE30) {
    // Get market config according to position
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(
      _marketIndex
    );

    _imrE30 = (_positionSizeE30 * _marketConfig.initialMarginFraction) / 1e18;
    return _imrE30;
  }

  /// @notice Calculate for Maintenance Margin Requirement from position size.
  /// @param _positionSizeE30 Size of position.
  /// @param _marketIndex Market Index from opening position.
  /// @return _mmrE30 The MMR amount required on position size, 30 decimals.
  function calculatePositionMMR(uint256 _positionSizeE30, uint256 _marketIndex) public view returns (uint256 _mmrE30) {
    // Get market config according to position
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(
      _marketIndex
    );

    _mmrE30 = (_positionSizeE30 * _marketConfig.maintenanceMarginFraction) / 1e18;
    return _mmrE30;
  }

  /// @notice This function returns the amount of free collateral available to a given sub-account
  /// @param _subAccount The address of the sub-account
  /// @param _price Price from limitOrder or Pyth
  /// @param _assetId AssetId of Market
  /// @return _freeCollateral The amount of free collateral available to the sub-account
  function getFreeCollateral(
    address _subAccount,
    uint256 _price,
    bytes32 _assetId
  ) public view returns (uint256 _freeCollateral) {
    uint256 equity = getEquity(_subAccount, _price, _assetId);
    uint256 imr = getIMR(_subAccount);

    _freeCollateral = equity - imr;
    return _freeCollateral;
  }
}
