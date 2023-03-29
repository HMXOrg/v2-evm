// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";
import { Owned } from "@hmx/base/Owned.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";

contract TradeHelper is ITradeHelper, ReentrancyGuard, Owned {
  uint32 internal constant BPS = 1e4;
  uint64 internal constant RATE_PRECISION = 1e18;

  /**
   * Events
   */
  event LogSettleTradingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleTradingFeeAmount(
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 devFeeAmount,
    uint256 protocolFeeAmount
  );
  event LogSettleBorrowingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleBorrowingFeeAmount(
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 devFeeAmount,
    uint256 plpFeeAmount
  );
  event LogSettleFundingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleFundingFeeAmount(address subAccount, address token, uint256 feeUsd, uint256 amount);

  event LogSettleUnRealizedPnlValue(address subAccount, uint256 usd);
  event LogSettleUnRealizedPnlAmount(address subAccount, address token, uint256 usd, uint256 amount);

  event LogSettleLiquidationFeeValue(address subAccount, uint256 usd);
  event LogSettleLiquidationFeeAmount(address subAccount, address token, uint256 usd, uint256 amount);

  event LogReceivedFundingFeeValue(address subAccount, uint256 feeUsd);
  event LogReceivedFundingFeeAmount(address subAccount, address token, uint256 feeUsd, uint256 amount);

  event LogReceivedUnRealizedPnlValue(address subAccount, uint256 usd);
  event LogReceivedUnRealizedPnlAmount(address subAccount, address token, uint256 usd, uint256 amount);

  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);

  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  Calculator public calculator; // cache this from configStorage

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
    // Sanity check
    ConfigStorage(_configStorage).calculator();
    VaultStorage(_vaultStorage).devFees(address(0));
    PerpStorage(_perpStorage).getGlobalState();

    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = Calculator(ConfigStorage(_configStorage).calculator());
  }

  function reloadConfig() external {
    // TODO: access control, sanity check, natspec
    // TODO: discuss about this pattern

    calculator = Calculator(ConfigStorage(configStorage).calculator());
  }

  /// @notice This function updates the borrowing rate for the given asset class index.
  /// @param _assetClassIndex The index of the asset class.
  function updateBorrowingRate(uint8 _assetClassIndex) external {
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    PerpStorage.GlobalAssetClass memory _globalAssetClass = _perpStorage.getGlobalAssetClassByIndex(_assetClassIndex);
    uint256 _fundingInterval = ConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastBorrowingTime = _globalAssetClass.lastBorrowingTime;

    // If last borrowing time is 0, set it to the nearest funding interval time and return.
    if (_lastBorrowingTime == 0) {
      _globalAssetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastBorrowingTime + _fundingInterval <= block.timestamp) {
      uint256 _plpTVL = calculator.getPLPValueE30(false);

      // update borrowing rate
      uint256 borrowingRate = calculator.getNextBorrowingRate(_assetClassIndex, _plpTVL);
      _globalAssetClass.sumBorrowingRate += borrowingRate;
      _globalAssetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;

      uint256 borrowingFee = (_globalAssetClass.reserveValueE30 * borrowingRate) / RATE_PRECISION;

      _globalAssetClass.sumBorrowingFeeE30 += borrowingFee;
    }
    _perpStorage.updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
  }

  /// @notice This function updates the funding rate for the given market index.
  /// @param _marketIndex The index of the market.
  function updateFundingRate(uint256 _marketIndex) external {
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(_marketIndex);

    uint256 _fundingInterval = ConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastFundingTime = _globalMarket.lastFundingTime;

    // If last funding time is 0, set it to the nearest funding interval time and return.
    if (_lastFundingTime == 0) {
      _globalMarket.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastFundingTime + _fundingInterval <= block.timestamp) {
      // update funding rate
      int256 nextFundingRate = calculator.getNextFundingRate(_marketIndex);
      int256 lastFundingRate = _globalMarket.currentFundingRate;
      _globalMarket.currentFundingRate += nextFundingRate;
      _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);

      if (_globalMarket.longPositionSize > 0) {
        int256 fundingFeeLongE30 = calculator.getFundingFee(
          _marketIndex,
          true,
          int(_globalMarket.longPositionSize),
          lastFundingRate
        );
        _globalMarket.accumFundingLong += fundingFeeLongE30;
      }

      if (_globalMarket.shortPositionSize > 0) {
        int256 fundingFeeShortE30 = calculator.getFundingFee(
          _marketIndex,
          false,
          int(_globalMarket.shortPositionSize),
          lastFundingRate
        );
        _globalMarket.accumFundingShort += fundingFeeShortE30;
      }

      _globalMarket.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);
    }
  }

  function settleAllFees(
    PerpStorage.Position memory _position,
    uint256 _absSizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external {
    address _subAccount = _getSubAccount(_position.primaryAccount, _position.subAccountId);

    (uint256 _tradingFeeToBePaid, uint256 _borrowingFeeToBePaid, int256 _fundingFeeToBePaid) = _calAllFees(
      _subAccount,
      _position,
      _absSizeDelta,
      _positionFeeBPS,
      _assetClassIndex,
      _marketIndex
    );

    _increaseCollateral(_subAccount, 0, _fundingFeeToBePaid);
    _decreaseCollateral(
      _subAccount,
      0,
      _fundingFeeToBePaid,
      _borrowingFeeToBePaid,
      _tradingFeeToBePaid,
      0,
      address(0),
      true
    );
  }

  function calAllFees(
    address _subAccount,
    PerpStorage.Position memory _position,
    uint256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external returns (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee) {
    (_tradingFee, _borrowingFee, _fundingFee) = _calAllFees(
      _subAccount,
      _position,
      _sizeDelta,
      _positionFeeBPS,
      _assetClassIndex,
      _marketIndex
    );
  }

  function _calAllFees(
    address _subAccount,
    PerpStorage.Position memory _position,
    uint256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) internal returns (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee) {
    _tradingFee = (_sizeDelta * _positionFeeBPS) / BPS;
    emit LogSettleTradingFeeValue(_subAccount, _tradingFee);

    _borrowingFee = calculator.getBorrowingFee(
      _assetClassIndex,
      _position.reserveValueE30,
      _position.entryBorrowingRate
    );
    _accumSettledBorrowingFee(_assetClassIndex, _borrowingFee);
    emit LogSettleBorrowingFeeValue(_subAccount, _borrowingFee);

    bool _isLong = _position.positionSizeE30 > 0;
    _fundingFee = calculator.getFundingFee(
      _marketIndex,
      _isLong,
      _position.positionSizeE30,
      _position.entryFundingRate
    );
    _isLong
      ? _updateAccumFundingLong(_marketIndex, -_fundingFee)
      : _updateAccumFundingShort(_marketIndex, -_fundingFee);
    emit LogSettleFundingFeeValue(_subAccount, uint256(_fundingFee));

    return (_tradingFee, _borrowingFee, _fundingFee);
  }

  function accumSettledBorrowingFee(uint256 _assetClassIndex, uint256 _borrowingFeeToBeSettled) external {
    _accumSettledBorrowingFee(_assetClassIndex, _borrowingFeeToBeSettled);
  }

  function _accumSettledBorrowingFee(uint256 _assetClassIndex, uint256 _borrowingFeeToBeSettled) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.GlobalAssetClass memory _globalAssetClass = _perpStorage.getGlobalAssetClassByIndex(
      uint8(_assetClassIndex)
    );
    _globalAssetClass.sumSettledBorrowingFeeE30 += _borrowingFeeToBeSettled;
    _perpStorage.updateGlobalAssetClass(uint8(_assetClassIndex), _globalAssetClass);
  }

  function increaseCollateral(address _subAccount, int256 _unrealizedPnl, int256 _fundingFee) external {
    _increaseCollateral(_subAccount, _unrealizedPnl, _fundingFee);
  }

  struct IncreaseCollateralVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    uint256 unrealizedPnlToBeReceived;
    uint256 fundingFeeToBeReceived;
    uint256 payerBalance;
    uint256 tokenPrice;
    address subAccount;
    address token;
    uint8 tokenDecimal;
  }

  function _increaseCollateral(address _subAccount, int256 _unrealizedPnl, int256 _fundingFee) internal {
    IncreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    _vars.subAccount = _subAccount;

    bytes32[] memory _plpAssetIds = _vars.configStorage.getPlpAssetIds();
    uint256 _len = _plpAssetIds.length;
    if (_unrealizedPnl > 0) {
      _vars.unrealizedPnlToBeReceived = uint256(_unrealizedPnl);
      emit LogReceivedUnRealizedPnlValue(_vars.subAccount, _vars.unrealizedPnlToBeReceived);
    }
    if (_fundingFee < 0) {
      _vars.fundingFeeToBeReceived = uint256(-_fundingFee);
      emit LogReceivedFundingFeeValue(_vars.subAccount, _vars.fundingFeeToBeReceived);
    }

    {
      for (uint256 i = 0; i < _len; ) {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_plpAssetIds[i]);
        _vars.tokenDecimal = _assetConfig.decimals;
        _vars.token = _assetConfig.tokenAddress;
        (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);

        {
          _vars.payerBalance = _vars.vaultStorage.fundingFeeReserve(_assetConfig.tokenAddress);
          if (_vars.payerBalance > 0 && _vars.fundingFeeToBeReceived > 0) {
            _increaseCollateralWithFundingFeeFromFeeReserve(_vars);
          }
        }

        unchecked {
          ++i;
        }
      }
    }
    {
      for (uint256 i = 0; i < _len; ) {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_plpAssetIds[i]);
        _vars.tokenDecimal = _assetConfig.decimals;
        _vars.token = _assetConfig.tokenAddress;
        (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);

        {
          _vars.payerBalance = _vars.vaultStorage.plpLiquidity(_assetConfig.tokenAddress);
          if (_vars.payerBalance > 0 && _vars.unrealizedPnlToBeReceived > 0) {
            _increaseCollateralWithUnrealizedPnlFromPlp(_vars);
          }
        }

        {
          _vars.payerBalance = _vars.vaultStorage.plpLiquidity(_assetConfig.tokenAddress);
          if (_vars.payerBalance > 0 && _vars.fundingFeeToBeReceived > 0) {
            _increaseCollateralWithFundingFeeFromPlp(_vars);
          }
        }

        unchecked {
          ++i;
        }
      }
    }
  }

  function _increaseCollateralWithUnrealizedPnlFromPlp(IncreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.unrealizedPnlToBeReceived,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    _vars.vaultStorage.payTraderProfit(_vars.subAccount, _vars.token, _repayAmount, 0);

    _vars.unrealizedPnlToBeReceived -= _repayValue;

    emit LogReceivedUnRealizedPnlAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
  }

  function _increaseCollateralWithFundingFeeFromFeeReserve(IncreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.fundingFeeToBeReceived,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    _vars.vaultStorage.payFundingFeeFromFundingFeeReserveToTrader(_vars.subAccount, _vars.token, _repayAmount);

    _vars.fundingFeeToBeReceived -= _repayValue;

    emit LogReceivedFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
  }

  function _increaseCollateralWithFundingFeeFromPlp(IncreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.fundingFeeToBeReceived,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    _vars.vaultStorage.borrowFundingFeeFromPlpToTrader(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

    _vars.fundingFeeToBeReceived -= _repayValue;

    emit LogReceivedFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
  }

  function decreaseCollateral(
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator,
    bool _isRevertOnError
  ) external {
    _decreaseCollateral(
      _subAccount,
      _unrealizedPnl,
      _fundingFee,
      _borrowingFee,
      _tradingFee,
      _liquidationFee,
      _liquidator,
      _isRevertOnError
    );
  }

  struct DecreaseCollateralVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    ConfigStorage.TradingConfig tradingConfig;
    uint256 unrealizedPnlToBePaid;
    uint256 tradingFeeToBePaid;
    uint256 borrowingFeeToBePaid;
    uint256 fundingFeeToBePaid;
    uint256 liquidationFeeToBePaid;
    uint256 payerBalance;
    uint256 plpDebt;
    uint256 tokenPrice;
    address subAccount;
    address token;
    uint8 tokenDecimal;
  }

  function _decreaseCollateral(
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator,
    bool _isRevertOnError
  ) internal {
    DecreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();

    _vars.subAccount = _subAccount;

    address[] memory _collateralTokens = _vars.vaultStorage.getTraderTokens(_vars.subAccount);
    uint256 _len = _collateralTokens.length;

    if (_unrealizedPnl < 0) {
      _vars.unrealizedPnlToBePaid = uint256(-_unrealizedPnl);
      emit LogSettleUnRealizedPnlValue(_vars.subAccount, _vars.unrealizedPnlToBePaid);
    }

    _vars.tradingFeeToBePaid = _tradingFee;
    emit LogSettleTradingFeeValue(_vars.subAccount, _vars.unrealizedPnlToBePaid);

    _vars.borrowingFeeToBePaid = _borrowingFee;
    emit LogSettleBorrowingFeeValue(_vars.subAccount, _vars.unrealizedPnlToBePaid);

    if (_fundingFee > 0) {
      _vars.fundingFeeToBePaid = uint256(_fundingFee);
      emit LogSettleFundingFeeValue(_vars.subAccount, _vars.unrealizedPnlToBePaid);
    }

    _vars.liquidationFeeToBePaid = _liquidationFee;
    emit LogSettleLiquidationFeeValue(_vars.subAccount, _vars.liquidationFeeToBePaid);

    for (uint256 i = 0; i < _len; ) {
      _vars.token = _collateralTokens[i];
      _vars.tokenDecimal = _vars.configStorage.getAssetTokenDecimal(_vars.token);
      (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(
        ConfigStorage(_vars.configStorage).tokenAssetIds(_vars.token),
        false
      );

      _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);

      {
        if (_vars.payerBalance > 0 && _vars.liquidationFeeToBePaid > 0) {
          _decreaseCollateralWithLiquidationFee(_vars, _liquidator);
        }
      }

      {
        if (_vars.payerBalance > 0 && _vars.borrowingFeeToBePaid > 0) {
          _decreaseCollateralWithBorrowingFeeToPlp(_vars);
        }
      }

      {
        if (_vars.payerBalance > 0 && _vars.tradingFeeToBePaid > 0) {
          _decreaseCollateralWithTradingFeeToProtocolFee(_vars);
        }
      }

      {
        _vars.plpDebt = _vars.vaultStorage.plpLiquidityDebtUSDE30();
        if (_vars.payerBalance > 0 && _vars.fundingFeeToBePaid > 0 && _vars.plpDebt > 0) {
          _decreaseCollateralWithFundingFeeToPlp(_vars);
        }
      }

      {
        if (_vars.payerBalance > 0 && _vars.fundingFeeToBePaid > 0) {
          _decreaseCollateralWithFundingFeeToFeeReserve(_vars);
        }
      }

      {
        if (_vars.payerBalance > 0 && _vars.unrealizedPnlToBePaid > 0) {
          _decreaseCollateralWithUnrealizedPnlToPlp(_vars);
        }
      }

      unchecked {
        ++i;
      }
    }

    // If fee cannot be covered, revert.
    // This shouldn't be happen unless the platform is suffering from bad debt
    if (_isRevertOnError && _vars.tradingFeeToBePaid > 0) revert ITradeHelper_TradingFeeCannotBeCovered();
    if (_isRevertOnError && _vars.borrowingFeeToBePaid > 0) revert ITradeHelper_BorrowingFeeCannotBeCovered();
    if (_isRevertOnError && _vars.fundingFeeToBePaid > 0) revert ITradeHelper_FundingFeeCannotBeCovered();
    if (_isRevertOnError && _vars.unrealizedPnlToBePaid > 0) revert ITradeHelper_UnrealizedPnlCannotBeCovered();
  }

  function _decreaseCollateralWithUnrealizedPnlToPlp(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.unrealizedPnlToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    VaultStorage(_vars.vaultStorage).payPlp(_vars.subAccount, _vars.token, _repayAmount);

    _vars.unrealizedPnlToBePaid -= _repayValue;
    _vars.payerBalance -= _repayAmount;

    emit LogSettleUnRealizedPnlAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
  }

  function _decreaseCollateralWithFundingFeeToPlp(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.plpDebt,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    _vars.vaultStorage.repayFundingFeeDebtFromTraderToPlp(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

    _vars.fundingFeeToBePaid -= _repayValue;
    _vars.payerBalance -= _repayAmount;

    emit LogSettleFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
  }

  function _decreaseCollateralWithFundingFeeToFeeReserve(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.fundingFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    _vars.vaultStorage.payFundingFeeFromTraderToFundingFeeReserve(_vars.subAccount, _vars.token, _repayAmount);

    _vars.fundingFeeToBePaid -= _repayValue;
    _vars.payerBalance -= _repayAmount;

    emit LogSettleFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
  }

  function _decreaseCollateralWithTradingFeeToProtocolFee(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.tradingFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    // devFee = tradingFee * devFeeRate
    uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
    // the rest after dev fee deduction belongs to protocol fee portion
    uint256 _protocolFeeAmount = _repayAmount - _devFeeAmount;

    // book those moving balances
    _vars.vaultStorage.payTradingFee(_vars.subAccount, _vars.token, _devFeeAmount, _protocolFeeAmount);

    // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
    _vars.tradingFeeToBePaid -= _repayValue;
    _vars.payerBalance -= _repayAmount;

    emit LogSettleTradingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _devFeeAmount, _protocolFeeAmount);
  }

  function _decreaseCollateralWithBorrowingFeeToPlp(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.borrowingFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    // devFee = tradingFee * devFeeRate
    uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
    // the rest after dev fee deduction belongs to plp liquidity
    uint256 _plpFeeAmount = _repayAmount - _devFeeAmount;

    // book those moving balances
    _vars.vaultStorage.payBorrowingFee(_vars.subAccount, _vars.token, _devFeeAmount, _plpFeeAmount);

    // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
    _vars.borrowingFeeToBePaid -= _repayValue;
    _vars.payerBalance -= _repayAmount;

    emit LogSettleBorrowingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _devFeeAmount, _plpFeeAmount);
  }

  function _decreaseCollateralWithLiquidationFee(DecreaseCollateralVars memory _vars, address _liquidator) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.liquidationFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    _vars.vaultStorage.transfer(_vars.token, _vars.subAccount, _liquidator, _repayAmount);

    _vars.liquidationFeeToBePaid -= _repayValue;
    _vars.payerBalance -= _repayAmount;

    emit LogSettleLiquidationFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
  }

  function _getRepayAmount(
    uint256 _payerBalance,
    uint256 _valueE30,
    uint256 _tokenPrice,
    uint8 _tokenDecimal
  ) internal pure returns (uint256 _repayAmount, uint256 _repayValueE30) {
    uint256 _feeAmount = (_valueE30 * (10 ** _tokenDecimal)) / _tokenPrice;

    if (_payerBalance > _feeAmount) {
      // _payerBalance can cover the rest of the fee
      return (_feeAmount, _valueE30);
    } else {
      // _payerBalance cannot cover the rest of the fee, just take the amount the trader have
      uint256 _payerBalanceValue = (_payerBalance * _tokenPrice) / (10 ** _tokenDecimal);
      return (_payerBalance, _payerBalanceValue);
    }
  }

  function _updateAccumFundingLong(uint256 _marketIndex, int256 fundingLong) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(_marketIndex);

    _globalMarket.accumFundingLong += fundingLong;
    _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);
  }

  function _updateAccumFundingShort(uint256 _marketIndex, int256 fundingShort) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(_marketIndex);

    _globalMarket.accumFundingShort += fundingShort;
    _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);
  }

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  /**
   * Setter
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external nonReentrant onlyOwner {
    if (_configStorage == address(0)) revert ITradeHelper_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external nonReentrant onlyOwner {
    if (_vaultStorage == address(0)) revert ITradeHelper_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;

    // Sanity check
    VaultStorage(_vaultStorage).devFees(address(0));
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external nonReentrant onlyOwner {
    if (_perpStorage == address(0)) revert ITradeHelper_InvalidAddress();

    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
  }
}
