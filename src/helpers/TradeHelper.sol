// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";

import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";
import { console2 } from "forge-std/console2.sol";

contract TradeHelper is ITradeHelper {
  uint32 internal constant BPS = 1e4;
  uint64 internal constant RATE_PRECISION = 1e18;

  event LogSettleTradingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleTradingFeeAmount(address subAccount, address token, uint256 devFeeAmount, uint256 protocolFeeAmount);

  event LogSettleBorrowingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleBorrowingFeeAmount(address subAccount, address token, uint256 devFeeAmount, uint256 plpFeeAmount);

  event LogSettleFundingFeeValue(address subAccount, int256 feeUsd);
  event LogSettleFundingFeeAmountWhenTraderPays(address subAccount, address token, uint256 amount);
  event LogSettleFundingFeeAmountWhenTraderReceives(address subAccount, address token, uint256 amount);

  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  Calculator public calculator; // cache this from configStorage

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
    // Sanity check
    // PerpStorage(_perpStorage).getGlobalState();
    // VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
    // ConfigStorage(_configStorage).getLiquidityConfig();

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
      int256 fundingFeeLong;
      int256 fundingFeeShort;
      int256 nextFundingRate = calculator.getNextFundingRate(_marketIndex);

      _globalMarket.currentFundingRate += nextFundingRate;

      if (_globalMarket.longPositionSize != 0) {
        fundingFeeLong = (_globalMarket.currentFundingRate * int(_globalMarket.longPositionSize)) / 1e30;
      }
      if (_globalMarket.shortPositionSize != 0) {
        fundingFeeShort = (_globalMarket.currentFundingRate * -int(_globalMarket.shortPositionSize)) / 1e30;
      }

      _globalMarket.accumFundingLong += fundingFeeLong;
      _globalMarket.accumFundingShort += fundingFeeShort;
      _globalMarket.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;

      _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);
    }
  }

  struct SettleAllFeesVars {
    // Share vars
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    PerpStorage perpStorage;
    OracleMiddleware oracle;
    ConfigStorage.TradingConfig tradingConfig;
    uint256 plpLiquidityDebtUSDE30;
    uint256 marketIndex;
    address[] collateralTokens;
    uint256 collateralTokensLength;
    address subAccount;
    uint256 tokenPrice;
    // Trading fee vars
    uint256 tradingFeeToBePaid;
    // Borrowing fee vars
    uint256 borrowingFeeToBePaid;
    // Funding fee vars
    int256 fundingFeeToBePaid;
    uint256 absFundingFeeToBePaid;
    uint8 tokenDecimal;
    bool isLong;
    bool traderMustPay;
  }

  function settleAllFees(
    PerpStorage.Position memory _position,
    uint256 _absSizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external {
    SettleAllFeesVars memory _vars;

    // SLOAD
    _vars.marketIndex = _marketIndex;
    _vars.perpStorage = PerpStorage(perpStorage);
    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.collateralTokens = _vars.configStorage.getCollateralTokens();
    _vars.collateralTokensLength = _vars.collateralTokens.length;
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();
    _vars.subAccount = _getSubAccount(_position.primaryAccount, _position.subAccountId);

    // Calculate the trading fee
    {
      _vars.tradingFeeToBePaid = (_absSizeDelta * _positionFeeBPS) / BPS;

      emit LogSettleTradingFeeValue(_vars.subAccount, _vars.tradingFeeToBePaid);
    }

    // Calculate the borrowing fee
    {
      _vars.borrowingFeeToBePaid = calculator.getBorrowingFee(
        _assetClassIndex,
        _position.reserveValueE30,
        _position.entryBorrowingRate
      );

      emit LogSettleBorrowingFeeValue(_vars.subAccount, _vars.borrowingFeeToBePaid);
    }

    // Calculate the funding fee
    {
      _vars.isLong = _position.positionSizeE30 > 0;
      _vars.fundingFeeToBePaid = calculator.getFundingFee(
        _marketIndex,
        _vars.isLong,
        _position.positionSizeE30,
        _position.entryFundingRate
      );
      _vars.absFundingFeeToBePaid = _abs(_vars.fundingFeeToBePaid);

      // If fundingFee is negative mean Trader receives Fee
      // If fundingFee is positive mean Trader pays Fee
      _vars.traderMustPay = (_vars.fundingFeeToBePaid > 0);

      emit LogSettleFundingFeeValue(_vars.subAccount, _vars.fundingFeeToBePaid);
    }

    // Update global state
    {
      _accumSettledBorrowingFee(_assetClassIndex, _vars.borrowingFeeToBePaid);
    }

    increaseCollateral(_vars.subAccount, 0, _vars.fundingFeeToBePaid);
    decreaseCollateral(
      _vars.subAccount,
      0,
      _vars.fundingFeeToBePaid,
      _vars.borrowingFeeToBePaid,
      _vars.tradingFeeToBePaid,
      0,
      address(0)
    );

    // If fee cannot be covered, revert.
    // This shouldn't be happen unless the platform is suffering from bad debt
    // if (_vars.tradingFeeToBePaid > 0) revert ITradeHelper_TradingFeeCannotBeCovered();
    // if (_vars.borrowingFeeToBePaid > 0) revert ITradeHelper_BorrowingFeeCannotBeCovered();
    // if (_vars.absFundingFeeToBePaid > 0) revert ITradeHelper_FundingFeeCannotBeCovered();
  }

  function _settleFundingFeeWhenTraderMustPay(
    SettleAllFeesVars memory _vars,
    address _collateralToken
  ) internal returns (uint256) {
    // PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_vars.marketIndex);

    // When trader is the payer
    uint256 _traderBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _collateralToken);

    // We are going to deduct trader balance,
    // so we need to check whether trader has this collateral token or not.
    // If not skip to next token
    if (_traderBalance > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _traderBalance,
        _vars.absFundingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );

      // book the balances
      _vars.vaultStorage.payFundingFeeFromTraderToFundingFeeReserve(_vars.subAccount, _collateralToken, _repayAmount);

      // @todo - split to withdraw surplus PR
      // // Update accum funding fee on Global storage for surplus calculation
      // if (_vars.isLong) {
      //   _globalMarket.accumFundingLong += int(_repayValue);
      // } else {
      //   _globalMarket.accumFundingShort += int(_repayValue);
      // }
      // _vars.perpStorage.updateGlobalMarket(_vars.marketIndex, _globalMarket);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.absFundingFeeToBePaid -= _repayValue;
    }
  }

  function _repayBorrowDebtFromTraderToPlp(SettleAllFeesVars memory _vars, address _collateralToken) internal {
    // PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_vars.marketIndex);

    // When trader is the payer
    uint256 _traderBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _collateralToken);

    // We are going to deduct trader balance,
    // so we need to check whether trader has this collateral token or not.
    // If not skip to next token
    if (_traderBalance > 0) {
      // If absFundingFeeToBePaid is less than borrowing debts from PLP, Then Trader repay with all current collateral amounts to PLP
      // Else Trader repay with just enough current collateral amounts to PLP
      uint256 repayFundingFeeValue = _vars.absFundingFeeToBePaid < _vars.plpLiquidityDebtUSDE30
        ? _vars.absFundingFeeToBePaid
        : _vars.plpLiquidityDebtUSDE30;

      // Trader repay with just enough current collateral amounts to PLP
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _traderBalance,
        repayFundingFeeValue,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      _vars.vaultStorage.repayFundingFeeDebtFromTraderToPlp(
        _vars.subAccount,
        _collateralToken,
        _repayAmount,
        _repayValue
      );

      // @todo - split to withdraw surplus PR
      // // Update accum funding fee on Global storage for surplus calculation
      // if (_vars.isLong) {
      //   _globalMarket.accumFundingLong += int(_repayValue);
      // } else {
      //   _globalMarket.accumFundingShort += int(_repayValue);
      // }
      // _vars.perpStorage.updateGlobalMarket(_vars.marketIndex, _globalMarket);

      _vars.absFundingFeeToBePaid -= _repayValue;
    }
  }

  function _settleFundingFeeWhenTraderMustReceive(
    SettleAllFeesVars memory _vars,
    address _collateralToken
  ) internal returns (uint256) {
    // PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_vars.marketIndex);

    // When funding fee is the payer
    uint256 _fundingFeeBalance = _vars.vaultStorage.fundingFeeReserve(_collateralToken);

    // We are going to deduct funding fee balance,
    // so we need to check whether funding fee has this collateral token or not.
    // If not skip to next token
    if (_fundingFeeBalance > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _fundingFeeBalance,
        _vars.absFundingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );

      // book the balances
      _vars.vaultStorage.payFundingFeeFromFundingFeeReserveToTrader(_vars.subAccount, _collateralToken, _repayAmount);

      // @todo - split to withdraw surplus PR
      // // Update accum funding fee on Global storage for surplus calculation
      // if (_vars.isLong) {
      //   _globalMarket.accumFundingLong -= int(_repayValue);
      // } else {
      //   _globalMarket.accumFundingShort -= int(_repayValue);
      // }
      // _vars.perpStorage.updateGlobalMarket(_vars.marketIndex, _globalMarket);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.absFundingFeeToBePaid -= _repayValue;
    }
  }

  function _settleFundingFeeWhenBorrowingFromPLP(SettleAllFeesVars memory _vars, address _collateralToken) internal {
    // PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_vars.marketIndex);

    // When plp liquidity is the payer
    uint256 _plpBalance = _vars.vaultStorage.plpLiquidity(_collateralToken);

    // We are going to deduct plp liquidity balance,
    // so we need to check whether plp has this collateral token or not.
    // If not skip to next token
    if (_plpBalance > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _plpBalance,
        _vars.absFundingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );

      // book the balances
      _vars.vaultStorage.borrowFundingFeeFromPlpToTrader(_vars.subAccount, _collateralToken, _repayAmount, _repayValue);

      // @todo - split to withdraw surplus PR
      // // Update accum funding fee on Global storage for surplus calculation
      // if (_vars.isLong) {
      //   _globalMarket.accumFundingLong -= int(_repayValue);
      // } else {
      //   _globalMarket.accumFundingShort -= int(_repayValue);
      // }
      // _vars.perpStorage.updateGlobalMarket(_vars.marketIndex, _globalMarket);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.absFundingFeeToBePaid -= _repayValue;

      emit LogSettleFundingFeeAmountWhenTraderReceives(_vars.subAccount, _collateralToken, _repayAmount);
    }
  }

  function _settleTradingFee(SettleAllFeesVars memory _vars, address _collateralToken) internal {
    // Get trader balance of each collateral
    uint256 _traderBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _collateralToken);

    // if trader has some of this collateral token, try cover the fee with it
    if (_traderBalance > 0) {
      // protocol fee portion + dev fee portion
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _traderBalance,
        _vars.tradingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );

      // devFee = tradingFee * devFeeRate
      uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
      // the rest after dev fee deduction belongs to protocol fee portion
      uint256 _protocolFeeAmount = _repayAmount - _devFeeAmount;

      // book those moving balances
      _vars.vaultStorage.payTradingFee(_vars.subAccount, _collateralToken, _devFeeAmount, _protocolFeeAmount);

      // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.tradingFeeToBePaid -= _repayValue;

      emit LogSettleTradingFeeAmount(_vars.subAccount, _collateralToken, _devFeeAmount, _protocolFeeAmount);
    }
    // else continue, as trader does not have any of this collateral token
  }

  function _settleBorrowingFee(SettleAllFeesVars memory _vars, address _collateralToken) internal {
    // Get trader balance of each collateral
    uint256 _traderBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _collateralToken);

    // if trader has some of this collateral token, try cover the fee with it
    if (_traderBalance > 0) {
      // plp fee portion + dev fee portion
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _traderBalance,
        _vars.borrowingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );

      // devFee = tradingFee * devFeeRate
      uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
      // the rest after dev fee deduction belongs to plp liquidity
      uint256 _plpFeeAmount = _repayAmount - _devFeeAmount;

      // book those moving balances
      _vars.vaultStorage.payBorrowingFee(_vars.subAccount, _collateralToken, _devFeeAmount, _plpFeeAmount);

      // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.borrowingFeeToBePaid -= _repayValue;

      emit LogSettleBorrowingFeeAmount(_vars.subAccount, _collateralToken, _devFeeAmount, _plpFeeAmount);
    }
    // else continue, as trader does not have any of this collateral token
  }

  function accumSettledBorrowingFee(uint256 _assetClassIndex, uint256 _borrowingFeeToBeSettled) external {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.GlobalAssetClass memory _globalAssetClass = _perpStorage.getGlobalAssetClassByIndex(
      uint8(_assetClassIndex)
    );
    _globalAssetClass.sumSettledBorrowingFeeE30 += _borrowingFeeToBeSettled;
    _perpStorage.updateGlobalAssetClass(uint8(_assetClassIndex), _globalAssetClass);
  }

  function _accumSettledBorrowingFee(uint256 _assetClassIndex, uint256 _borrowingFeeToBeSettled) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.GlobalAssetClass memory _globalAssetClass = _perpStorage.getGlobalAssetClassByIndex(
      uint8(_assetClassIndex)
    );
    _globalAssetClass.sumSettledBorrowingFeeE30 += _borrowingFeeToBeSettled;
    _perpStorage.updateGlobalAssetClass(uint8(_assetClassIndex), _globalAssetClass);
  }

  struct IncreaseCollateralVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    uint256 unrealizedPnlToBeReceive;
    uint256 fundingFeeToBeReceive;
    uint256 payerBalance;
    // uint256 valueE30;
    uint256 tokenPrice;
    address subAccount;
    address token;
    uint8 tokenDecimal;
  }

  function increaseCollateral(address _subAccount, int256 _unrealizedPnl, int256 _fundingFee) public {
    IncreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    _vars.subAccount = _subAccount;

    bytes32[] memory _plpAssetIds = _vars.configStorage.getPlpAssetIds();
    uint256 _len = _plpAssetIds.length;
    if (_unrealizedPnl > 0) _vars.unrealizedPnlToBeReceive = uint256(_unrealizedPnl);
    if (_fundingFee < 0) _vars.fundingFeeToBeReceive = uint256(-_fundingFee);
    for (uint256 i = 0; i < _len; ) {
      ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_plpAssetIds[i]);
      _vars.tokenDecimal = _assetConfig.decimals;
      _vars.token = _assetConfig.tokenAddress;
      (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);

      {
        _vars.payerBalance = _vars.vaultStorage.plpLiquidity(_assetConfig.tokenAddress);
        if (_vars.payerBalance > 0 && _vars.unrealizedPnlToBeReceive > 0) {
          _increaseCollateralWithUnrealizedPnlFromPlp(_vars);
        }
      }

      {
        _vars.payerBalance = _vars.vaultStorage.fundingFeeReserve(_assetConfig.tokenAddress);
        if (_vars.payerBalance > 0 && _vars.fundingFeeToBeReceive > 0) {
          _increaseCollateralWithFundingFeeFromFeeReserve(_vars);
        }
      }

      {
        _vars.payerBalance = _vars.vaultStorage.plpLiquidity(_assetConfig.tokenAddress);
        if (_vars.payerBalance > 0 && _vars.fundingFeeToBeReceive > 0) {
          _increaseCollateralWithFundingFeeFromPlp(_vars);
        }
      }

      unchecked {
        ++i;
      }
    }
  }

  function _increaseCollateralWithUnrealizedPnlFromPlp(IncreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.unrealizedPnlToBeReceive,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("+_pnl", _repayAmount);
    _vars.vaultStorage.payTraderProfit(_vars.subAccount, _vars.token, _repayAmount, 0);

    _vars.unrealizedPnlToBeReceive -= _repayValue;
  }

  function _increaseCollateralWithFundingFeeFromFeeReserve(IncreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.fundingFeeToBeReceive,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("+_fundingfee_1", _repayAmount);
    _vars.vaultStorage.payFundingFeeFromFundingFeeReserveToTrader(_vars.subAccount, _vars.token, _repayAmount);

    _vars.fundingFeeToBeReceive -= _repayValue;
  }

  function _increaseCollateralWithFundingFeeFromPlp(IncreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.fundingFeeToBeReceive,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("+_fundingfee_2", _repayAmount);
    _vars.vaultStorage.borrowFundingFeeFromPlpToTrader(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

    _vars.fundingFeeToBeReceive -= _repayValue;
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
    // uint256 valueE30;
    uint256 tokenPrice;
    address subAccount;
    address token;
    uint8 tokenDecimal;
  }

  function decreaseCollateral(
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator
  ) public {
    DecreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();

    _vars.subAccount = _subAccount;

    address[] memory _collateralTokens = _vars.vaultStorage.getTraderTokens(_vars.subAccount);
    uint256 _len = _collateralTokens.length;
    if (_unrealizedPnl < 0) _vars.unrealizedPnlToBePaid = uint256(-_unrealizedPnl);
    if (_fundingFee > 0) _vars.fundingFeeToBePaid = uint256(_fundingFee);
    _vars.borrowingFeeToBePaid = _borrowingFee;
    _vars.tradingFeeToBePaid = _tradingFee;
    _vars.liquidationFeeToBePaid = _liquidationFee;
    for (uint256 i = 0; i < _len; ) {
      _vars.token = _collateralTokens[i];
      _vars.tokenDecimal = _vars.configStorage.getAssetTokenDecimal(_vars.token);
      (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(
        ConfigStorage(_vars.configStorage).tokenAssetIds(_vars.token),
        false
      );

      {
        _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
        console2.log("balance 1", _vars.payerBalance);
        if (_vars.payerBalance > 0 && _vars.liquidationFeeToBePaid > 0) {
          _decreaseCollateralWithLiquidationFee(_vars, _liquidator);
        }
      }

      {
        _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
        console2.log("balance 6", _vars.payerBalance);
        if (_vars.payerBalance > 0 && _vars.borrowingFeeToBePaid > 0) {
          _decreaseCollateralWithBorrowingFeeToPlp(_vars);
        }
      }

      {
        _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
        console2.log("balance 5", _vars.payerBalance);
        if (_vars.payerBalance > 0 && _vars.tradingFeeToBePaid > 0) {
          _decreaseCollateralWithTradingFeeToProtocolFee(_vars);
        }
      }

      {
        _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
        _vars.plpDebt = _vars.vaultStorage.plpLiquidityDebtUSDE30();
        console2.log("balance 3", _vars.payerBalance);
        if (_vars.payerBalance > 0 && _vars.fundingFeeToBePaid > 0 && _vars.plpDebt > 0) {
          _decreaseCollateralWithFundingFeeToPlp(_vars);
        }
      }

      {
        _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
        console2.log("balance 4", _vars.payerBalance);
        if (_vars.payerBalance > 0 && _vars.fundingFeeToBePaid > 0) {
          _decreaseCollateralWithFundingFeeToFeeReserve(_vars);
        }
      }

      {
        _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
        console2.log("balance 2", _vars.payerBalance);
        if (_vars.payerBalance > 0 && _vars.unrealizedPnlToBePaid > 0) {
          _decreaseCollateralWithUnrealizedPnlToPlp(_vars);
        }
      }

      unchecked {
        ++i;
      }
    }
    uint256 _badDebt = _vars.unrealizedPnlToBePaid +
      _vars.fundingFeeToBePaid +
      _vars.tradingFeeToBePaid +
      _vars.borrowingFeeToBePaid;
    if (_badDebt != 0) PerpStorage(perpStorage).addBadDebt(_vars.subAccount, _badDebt);
  }

  function _decreaseCollateralWithUnrealizedPnlToPlp(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.unrealizedPnlToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("-_pnl", _repayAmount);
    VaultStorage(_vars.vaultStorage).payPlp(_vars.subAccount, _vars.token, _repayAmount);

    _vars.unrealizedPnlToBePaid -= _repayValue;
  }

  function _decreaseCollateralWithFundingFeeToPlp(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.fundingFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("-_fundingfee_1", _repayAmount);
    _vars.vaultStorage.repayFundingFeeDebtFromTraderToPlp(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

    _vars.fundingFeeToBePaid -= _repayValue;
  }

  function _decreaseCollateralWithFundingFeeToFeeReserve(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.fundingFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("-_fundingfee_2", _repayAmount);
    _vars.vaultStorage.payFundingFeeFromTraderToFundingFeeReserve(_vars.subAccount, _vars.token, _repayAmount);

    _vars.fundingFeeToBePaid -= _repayValue;
  }

  function _decreaseCollateralWithTradingFeeToProtocolFee(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.tradingFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("-_tradingfee", _repayAmount);
    // devFee = tradingFee * devFeeRate
    uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
    // the rest after dev fee deduction belongs to protocol fee portion
    uint256 _protocolFeeAmount = _repayAmount - _devFeeAmount;

    // book those moving balances
    _vars.vaultStorage.payTradingFee(_vars.subAccount, _vars.token, _devFeeAmount, _protocolFeeAmount);

    // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
    _vars.tradingFeeToBePaid -= _repayValue;
  }

  function _decreaseCollateralWithBorrowingFeeToPlp(DecreaseCollateralVars memory _vars) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.borrowingFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("-_borrowing", _repayAmount);
    // devFee = tradingFee * devFeeRate
    uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
    // the rest after dev fee deduction belongs to plp liquidity
    uint256 _plpFeeAmount = _repayAmount - _devFeeAmount;

    // book those moving balances
    _vars.vaultStorage.payBorrowingFee(_vars.subAccount, _vars.token, _devFeeAmount, _plpFeeAmount);

    // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
    _vars.borrowingFeeToBePaid -= _repayValue;
  }

  function _decreaseCollateralWithLiquidationFee(DecreaseCollateralVars memory _vars, address _liquidator) internal {
    (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
      _vars.payerBalance,
      _vars.liquidationFeeToBePaid,
      _vars.tokenPrice,
      _vars.tokenDecimal
    );
    console2.log("-_liquidationfee", _repayAmount);
    _vars.vaultStorage.transfer(_vars.token, _vars.subAccount, _liquidator, _repayAmount);

    _vars.liquidationFeeToBePaid -= _repayValue;
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

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }
}
