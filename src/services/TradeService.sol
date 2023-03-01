// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

// @todo - refactor, deduplicate code
contract TradeService is ITradeService {
  using AddressUtils for address;

  // struct
  struct IncreasePositionVars {
    address subAccount;
    bytes32 positionId;
    bool isLong;
    bool isNewPosition;
    bool currentPositionIsLong;
    uint256 priceE30;
  }
  struct DecreasePositionVars {
    address subAccount;
    bytes32 positionId;
    uint256 absPositionSizeE30;
    uint256 avgEntryPriceE30;
    uint256 priceE30;
    int256 currentPositionSizeE30;
    bool isLongPosition;
  }

  // events
  // @todo - modify event parameters
  event LogDecreasePosition(bytes32 indexed _positionId, uint256 _decreasedSize);

  event LogCollectTradingFee(address account, uint256 assetClass, uint256 feeUsd);

  event LogCollectBorrowingFee(address account, uint256 assetClass, uint256 feeUsd);

  event LogCollectFundingFee(address account, uint256 assetClass, int256 feeUsd);

  event ForceClosePosition(
    address indexed _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    uint256 _closedPositionSize,
    uint256 _realizedProfit
  );

  /**
   * States
   */
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
    // @todo - sanity check
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
  }

  function increasePosition(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta
  ) external {
    IncreasePositionVars memory vars;

    // get the sub-account from the primary account and sub-account ID
    vars.subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // get the position for the given sub-account and market index
    vars.positionId = _getPositionId(vars.subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage).getPositionById(vars.positionId);

    // get the market configuration for the given market index
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(
      _marketIndex
    );

    // check size delta
    if (_sizeDelta == 0) revert ITradeService_BadSizeDelta();

    // check allow increase position
    if (!_marketConfig.allowIncreasePosition) revert ITradeService_NotAllowIncrease();

    // determine whether the new size delta is for a long position
    vars.isLong = _sizeDelta > 0;

    vars.isNewPosition = _position.positionSizeE30 == 0;

    // Pre validation
    // Verify that the number of positions has exceeds
    {
      if (
        vars.isNewPosition &&
        IConfigStorage(configStorage).getTradingConfig().maxPosition <
        IPerpStorage(perpStorage).getNumberOfSubAccountPosition(vars.subAccount) + 1
      ) revert ITradeService_BadNumberOfPosition();
    }

    vars.currentPositionIsLong = _position.positionSizeE30 > 0;
    // Verify that the current position has the same exposure direction
    if (!vars.isNewPosition && vars.currentPositionIsLong != vars.isLong) revert ITradeService_BadExposure();

    // Update borrowing rate
    updateBorrowingRate(_marketConfig.assetClass);

    // Update funding rate
    updateFundingRate(_marketIndex);

    // get the global market for the given market index
    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(_marketIndex);

    // market validation
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      // Get Price market.
      (vars.priceE30, _lastPriceUpdated, _marketStatus) = IOracleMiddleware(IConfigStorage(configStorage).oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          _marketConfig.exponent,
          vars.isLong, // if current position is SHORT position, then we use max price
          _marketConfig.priceConfidentThreshold,
          30, // @todo - move trust price age to config, the problem now is stack too deep at MarketConfig struct
          (int(_globalMarket.longOpenInterest) - int(_globalMarket.shortOpenInterest)),
          _sizeDelta,
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();

      // check sub account equity is under MMR
      _subAccountHealthCheck(vars.subAccount);
    }

    // get the absolute value of the new size delta
    uint256 _absSizeDelta = abs(_sizeDelta);

    // if the position size is zero, set the average price to the current price (new position)
    if (vars.isNewPosition) {
      _position.avgEntryPriceE30 = vars.priceE30;
      _position.primaryAccount = _primaryAccount;
      _position.subAccountId = _subAccountId;
      _position.marketIndex = _marketIndex;
    }

    // if the position size is not zero and the new size delta is not zero, calculate the new average price (adjust position)
    if (!vars.isNewPosition) {
      _position.avgEntryPriceE30 = _getPositionNextAveragePrice(
        abs(_position.positionSizeE30),
        vars.isLong,
        _absSizeDelta,
        vars.priceE30,
        _position.avgEntryPriceE30
      );
    }

    // MarginFee = Trading Fee + Borrowing Fee
    collectMarginFee(
      vars.subAccount,
      _absSizeDelta,
      _marketConfig.assetClass,
      _position.reserveValueE30,
      _position.entryBorrowingRate,
      _marketConfig.increasePositionFeeRate
    );

    settleMarginFee(vars.subAccount);

    // Collect funding fee
    collectFundingFee(
      vars.subAccount,
      _marketConfig.assetClass,
      _marketIndex,
      _position.positionSizeE30,
      _position.entryFundingRate
    );

    settleFundingFee(vars.subAccount);

    // update the position size by adding the new size delta
    _position.positionSizeE30 += _sizeDelta;

    {
      IPerpStorage.GlobalAssetClass memory _globalAssetClass = IPerpStorage(perpStorage).getGlobalAssetClassByIndex(
        _marketConfig.assetClass
      );
      _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(_position.marketIndex);

      _position.entryBorrowingRate = _globalAssetClass.sumBorrowingRate;
      _position.entryFundingRate = _globalMarket.currentFundingRate;
    }

    // if the position size is zero after the update, revert the transaction with an error
    if (_position.positionSizeE30 == 0) revert ITradeService_BadPositionSize();

    {
      // calculate the initial margin required for the new position
      uint256 _imr = (_absSizeDelta * _marketConfig.initialMarginFraction) / 1e18;

      // get the amount of free collateral available for the sub-account
      uint256 subAccountFreeCollateral = ICalculator(IConfigStorage(configStorage).calculator()).getFreeCollateral(
        vars.subAccount
      );
      // if the free collateral is less than the initial margin required, revert the transaction with an error
      if (subAccountFreeCollateral < _imr) revert ITradeService_InsufficientFreeCollateral();

      // calculate the maximum amount of reserve required for the new position
      uint256 _maxReserve = (_imr * _marketConfig.maxProfitRate) / 1e18;
      // increase the reserved amount by the maximum reserve required for the new position
      increaseReserved(_marketConfig.assetClass, _maxReserve);
      _position.reserveValueE30 += _maxReserve;
    }

    {
      // calculate the change in open interest for the new position
      uint256 _changedOpenInterest = (_absSizeDelta * 1e18) / vars.priceE30; // @todo - use decimal asset
      _position.openInterest += _changedOpenInterest;
      _position.lastIncreaseTimestamp = block.timestamp;

      // update global market state
      if (vars.isLong) {
        uint256 _nextAvgPrice = _globalMarket.longPositionSize == 0
          ? vars.priceE30
          : _calculateLongAveragePrice(_globalMarket, vars.priceE30, _sizeDelta, 0);

        IPerpStorage(perpStorage).updateGlobalLongMarketById(
          _marketIndex,
          _globalMarket.longPositionSize + _absSizeDelta,
          _nextAvgPrice,
          _globalMarket.longOpenInterest + _changedOpenInterest
        );
      } else {
        // to increase SHORT position sizeDelta should be negative
        uint256 _nextAvgPrice = _globalMarket.shortPositionSize == 0
          ? vars.priceE30
          : _calculateShortAveragePrice(_globalMarket, vars.priceE30, _sizeDelta, 0);

        IPerpStorage(perpStorage).updateGlobalShortMarketById(
          _marketIndex,
          _globalMarket.shortPositionSize + _absSizeDelta,
          _nextAvgPrice,
          _globalMarket.shortOpenInterest + _changedOpenInterest
        );
      }
    }

    // save the updated position to the storage
    IPerpStorage(perpStorage).savePosition(vars.subAccount, vars.positionId, _position);
  }

  // @todo - rewrite description
  /// @notice decrease trader position
  /// @param _account - address
  /// @param _subAccountId - address
  /// @param _marketIndex - market index
  /// @param _positionSizeE30ToDecrease - position size to decrease
  /// @param _tpToken - take profit token
  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease,
    address _tpToken
  ) external {
    if (_account != msg.sender) revert ITradeService_NotPositionOwner();

    // init vars
    DecreasePositionVars memory _vars;

    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(
      _marketIndex
    );

    _vars.subAccount = _getSubAccount(_account, _subAccountId);
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage).getPositionById(_vars.positionId);

    // Pre validation
    // if position size is 0 means this position is already closed
    _vars.currentPositionSizeE30 = _position.positionSizeE30;
    if (_vars.currentPositionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();

    _vars.isLongPosition = _vars.currentPositionSizeE30 > 0;

    // convert position size to be uint256
    _vars.absPositionSizeE30 = uint256(
      _vars.isLongPosition ? _vars.currentPositionSizeE30 : -_vars.currentPositionSizeE30
    );

    // position size to decrease is greater then position size, should be revert
    if (_positionSizeE30ToDecrease > _vars.absPositionSizeE30) revert ITradeService_DecreaseTooHighPositionSize();

    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(_marketIndex);

    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      (_vars.priceE30, _lastPriceUpdated, _marketStatus) = IOracleMiddleware(IConfigStorage(configStorage).oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          _marketConfig.exponent,
          !_vars.isLongPosition, // if current position is SHORT position, then we use max price
          _marketConfig.priceConfidentThreshold,
          30, // @todo - move trust price age to config, the problem now is stack too deep at MarketConfig struct
          (int(_globalMarket.longOpenInterest) - int(_globalMarket.shortOpenInterest)),
          _vars.isLongPosition ? -int(_positionSizeE30ToDecrease) : int(_positionSizeE30ToDecrease),
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();

      // check sub account equity is under MMR
      _subAccountHealthCheck(_vars.subAccount);
    }

    // update position, market, and global market state
    _decreasePosition(_marketConfig, _marketIndex, _position, _vars, _positionSizeE30ToDecrease, _tpToken);
  }

  // @todo - access control
  /// @notice force close trader position with maximum profit could take
  /// @param _account position owner
  /// @param _subAccountId sub-account id
  /// @param _marketIndex position market index
  /// @param _tpToken take profit token
  function forceClosePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    address _tpToken
  ) external {
    // init vars
    DecreasePositionVars memory _vars;

    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(
      _marketIndex
    );

    _vars.subAccount = _getSubAccount(_account, _subAccountId);
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage).getPositionById(_vars.positionId);

    // Pre validation
    // if position size is 0 means this position is already closed
    _vars.currentPositionSizeE30 = _position.positionSizeE30;
    if (_vars.currentPositionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();

    _vars.isLongPosition = _vars.currentPositionSizeE30 > 0;

    // convert position size to be uint256
    _vars.absPositionSizeE30 = uint256(
      _vars.isLongPosition ? _vars.currentPositionSizeE30 : -_vars.currentPositionSizeE30
    );

    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(_marketIndex);

    {
      uint8 _marketStatus;

      (_vars.priceE30, , _marketStatus) = IOracleMiddleware(IConfigStorage(configStorage).oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          _marketConfig.exponent,
          !_vars.isLongPosition, // if current position is SHORT position, then we use max price
          _marketConfig.priceConfidentThreshold,
          30, // @todo - move trust price age to config, the problem now is stack too deep at MarketConfig struct
          (int(_globalMarket.longOpenInterest) - int(_globalMarket.shortOpenInterest)),
          -_vars.currentPositionSizeE30,
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();

      // check sub account equity is under MMR
      _subAccountHealthCheck(_vars.subAccount);
    }

    // get pnl to check this position is reach to condition to auto take profit or not
    (bool isProfit, uint256 pnl) = getDelta(
      _vars.absPositionSizeE30,
      _vars.isLongPosition,
      _vars.priceE30,
      _position.avgEntryPriceE30
    );

    // When this position has profit and realized profit has >= reserved amount, then we force to close position
    if (!isProfit || pnl < _position.reserveValueE30) revert ITradeService_ReservedValueStillEnough();

    // update position, market, and global market state
    _decreasePosition(_marketConfig, _marketIndex, _position, _vars, _vars.absPositionSizeE30, _tpToken);

    emit ForceClosePosition(
      _account,
      _subAccountId,
      _marketIndex,
      _tpToken,
      _vars.absPositionSizeE30,
      pnl > _position.reserveValueE30 ? _position.reserveValueE30 : pnl
    );
  }

  /// @notice decrease trader position
  /// @param _marketConfig - target market config
  /// @param _globalMarketIndex - global market index
  /// @param _position - position info
  /// @param _vars - decrease criteria
  /// @param _positionSizeE30ToDecrease - position size to decrease
  /// @param _tpToken - take profit token
  function _decreasePosition(
    IConfigStorage.MarketConfig memory _marketConfig,
    uint256 _globalMarketIndex,
    IPerpStorage.Position memory _position,
    DecreasePositionVars memory _vars,
    uint256 _positionSizeE30ToDecrease,
    address _tpToken
  ) internal {
    // Update borrowing rate
    updateBorrowingRate(_marketConfig.assetClass);

    // Update funding rate
    updateFundingRate(_globalMarketIndex);

    // @todo - update funding & borrowing fee rate
    // @todo - calculate trading, borrowing and funding fee
    // @todo - collect fee
    collectMarginFee(
      _vars.subAccount,
      _positionSizeE30ToDecrease,
      _marketConfig.assetClass,
      _position.reserveValueE30,
      _position.entryBorrowingRate,
      _marketConfig.decreasePositionFeeRate
    );

    settleMarginFee(_vars.subAccount);

    // Collect funding fee
    collectFundingFee(
      _vars.subAccount,
      _marketConfig.assetClass,
      _globalMarketIndex,
      _position.positionSizeE30,
      _position.entryFundingRate
    );

    settleFundingFee(_vars.subAccount);

    uint256 _newAbsPositionSizeE30 = _vars.absPositionSizeE30 - _positionSizeE30ToDecrease;

    // check position is too tiny
    // @todo - now validate this at 1 USD, design where to keep this config
    //       due to we has problem stack too deep in MarketConfig now
    if (_newAbsPositionSizeE30 > 0 && _newAbsPositionSizeE30 < 1e30) revert ITradeService_TooTinyPosition();

    /**
     * calculate realized profit & loss
     */
    int256 _realizedPnl;
    {
      _vars.avgEntryPriceE30 = _position.avgEntryPriceE30;
      (bool isProfit, uint256 pnl) = getDelta(
        _vars.absPositionSizeE30,
        _vars.isLongPosition,
        _vars.priceE30,
        _vars.avgEntryPriceE30
      );
      // if trader has profit more than our reserved value then trader's profit maximum is reserved value
      if (pnl > _position.reserveValueE30) {
        pnl = _position.reserveValueE30;
      }
      if (isProfit) {
        _realizedPnl = int256((pnl * _positionSizeE30ToDecrease) / _vars.absPositionSizeE30);
      } else {
        _realizedPnl = -int256((pnl * _positionSizeE30ToDecrease) / _vars.absPositionSizeE30);
      }
    }

    /**
     *  update perp storage
     */
    {
      uint256 _openInterestDelta = (_position.openInterest * _positionSizeE30ToDecrease) / _vars.absPositionSizeE30;

      IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(
        _globalMarketIndex
      );

      // @todo - is close position then we should delete positions[x]
      bool isClosePosition = _newAbsPositionSizeE30 == 0;

      if (_vars.isLongPosition) {
        uint256 _nextAvgPrice = _calculateLongAveragePrice(
          _globalMarket,
          _vars.priceE30,
          -int256(_positionSizeE30ToDecrease),
          _realizedPnl
        );
        IPerpStorage(perpStorage).updateGlobalLongMarketById(
          _globalMarketIndex,
          _globalMarket.longPositionSize - _positionSizeE30ToDecrease,
          _nextAvgPrice,
          _globalMarket.longOpenInterest - _openInterestDelta
        );
      } else {
        uint256 _nextAvgPrice = _calculateShortAveragePrice(
          _globalMarket,
          _vars.priceE30,
          int256(_positionSizeE30ToDecrease),
          _realizedPnl
        );
        IPerpStorage(perpStorage).updateGlobalShortMarketById(
          _globalMarketIndex,
          _globalMarket.shortPositionSize - _positionSizeE30ToDecrease,
          _nextAvgPrice,
          _globalMarket.shortOpenInterest - _openInterestDelta
        );
      }
      IPerpStorage.GlobalState memory _globalState = IPerpStorage(perpStorage).getGlobalState();
      IPerpStorage.GlobalAssetClass memory _globalAssetClass = IPerpStorage(perpStorage).getGlobalAssetClassByIndex(
        _marketConfig.assetClass
      );

      // update global storage
      // to calculate new global reserve = current global reserve - reserve delta (position reserve * (position size delta / current position size))
      _globalState.reserveValueE30 -=
        (_position.reserveValueE30 * _positionSizeE30ToDecrease) /
        _vars.absPositionSizeE30;
      _globalAssetClass.reserveValueE30 -=
        (_position.reserveValueE30 * _positionSizeE30ToDecrease) /
        _vars.absPositionSizeE30;
      IPerpStorage(perpStorage).updateGlobalState(_globalState);
      IPerpStorage(perpStorage).updateGlobalAssetClass(_marketConfig.assetClass, _globalAssetClass);

      // update position info
      _position.entryBorrowingRate = _globalAssetClass.sumBorrowingRate;
      _position.entryFundingRate = _globalMarket.currentFundingRate;
      _position.positionSizeE30 = _vars.isLongPosition
        ? int256(_newAbsPositionSizeE30)
        : -int256(_newAbsPositionSizeE30);
      _position.reserveValueE30 =
        (((_newAbsPositionSizeE30 * _marketConfig.initialMarginFraction) / 1e18) * _marketConfig.maxProfitRate) /
        1e18;
      _position.avgEntryPriceE30 = isClosePosition ? 0 : _vars.avgEntryPriceE30;
      _position.openInterest = _position.openInterest - _openInterestDelta;
      _position.realizedPnl += _realizedPnl;
      IPerpStorage(perpStorage).savePosition(_vars.subAccount, _vars.positionId, _position);
    }

    {
      /**
       * settle profit & loss
       */
      if (_realizedPnl != 0) {
        if (_realizedPnl > 0) {
          // profit, trader should receive take profit token = Profit in USD
          _settleProfit(_vars.subAccount, _tpToken, uint256(_realizedPnl));
        } else {
          // loss
          _settleLoss(_vars.subAccount, uint256(-_realizedPnl));
        }
      }
    }

    /**
     * settle profit & loss
     */

    // check sub account equity is under MMR
    _subAccountHealthCheck(_vars.subAccount);

    emit LogDecreasePosition(_vars.positionId, _positionSizeE30ToDecrease);
  }

  /// @notice settle profit
  /// @param _token - token that trader want to take profit as collateral
  /// @param _realizedProfitE30 - trader profit in USD
  function _settleProfit(address _subAccount, address _token, uint256 _realizedProfitE30) internal {
    (uint256 _tpTokenPrice, ) = IOracleMiddleware(IConfigStorage(configStorage).oracle()).getLatestPrice(
      _token.toBytes32(),
      false,
      IConfigStorage(configStorage).getMarketConfigByToken(_token).priceConfidentThreshold,
      30 // trust price age (seconds) todo: from market config
    );

    // calculate token trader should received
    uint256 _tpTokenOut = (_realizedProfitE30 * 1e18) / _tpTokenPrice; // @todo - token decimal

    uint256 _settlementFeeRate = ICalculator(IConfigStorage(configStorage).calculator()).getSettlementFeeRate(
      _token,
      _realizedProfitE30
    );

    uint256 _settlementFee = (_tpTokenOut * _settlementFeeRate) / 1e18; // @todo - token decimal

    IVaultStorage(vaultStorage).removePLPLiquidity(_token, _tpTokenOut);
    IVaultStorage(vaultStorage).addFee(_token, _settlementFee);
    IVaultStorage(vaultStorage).increaseTraderBalance(_subAccount, _token, _tpTokenOut - _settlementFee);

    // @todo - emit LogSettleProfit(trader, collateralToken, addedAmount, settlementFee)
  }

  /// @notice settle loss
  /// @param _subAccount - Sub-account of trader
  /// @param _debtUsd - Loss in USD
  function _settleLoss(address _subAccount, uint256 _debtUsd) internal {
    address[] memory _plpTokens = IConfigStorage(configStorage).getPlpTokens();

    uint256 _len = _plpTokens.length;
    address _token;
    uint256 _collateral;
    uint256 _price;
    uint256 _collateralToRemove;
    uint256 _collateralUsd;
    // Loop through all the plp underlying tokens for the sub-account
    for (uint256 _i; _i < _len; ) {
      _token = _plpTokens[_i];
      // Sub-account plp collateral
      _collateral = IVaultStorage(vaultStorage).traderBalances(_subAccount, _token);

      // continue settle when sub-account has collateral, else go to check next token
      if (_collateral != 0) {
        // Retrieve the latest price and confident threshold of the plp underlying token
        (_price, ) = IOracleMiddleware(IConfigStorage(configStorage).oracle()).getLatestPrice(
          _token.toBytes32(),
          false,
          IConfigStorage(configStorage).getMarketConfigByToken(_token).priceConfidentThreshold,
          30 // @todo - should from config
        );

        _collateralUsd = (_collateral * _price) / 1e18; // @todo - token decimal

        if (_collateralUsd >= _debtUsd) {
          // When this collateral token can cover all the debt, use this token to pay it all
          _collateralToRemove = (_debtUsd * 1e18) / _price; // @todo - token decimal

          IVaultStorage(vaultStorage).addPLPLiquidity(_token, _collateralToRemove);
          IVaultStorage(vaultStorage).decreaseTraderBalance(_subAccount, _token, _collateralToRemove);
          // @todo - emit LogSettleLoss(trader, collateralToken, deductedAmount)
          // In this case, all debt are paid. We can break the loop right away.
          break;
        } else {
          // When this collateral token cannot cover all the debt, use this token to pay debt as much as possible
          _collateralToRemove = (_collateralUsd * 1e18) / _price; // @todo - token decimal

          IVaultStorage(vaultStorage).addPLPLiquidity(_token, _collateralToRemove);
          IVaultStorage(vaultStorage).decreaseTraderBalance(_subAccount, _token, _collateralToRemove);
          // @todo - emit LogSettleLoss(trader, collateralToken, deductedAmount)
          // update debtUsd
          unchecked {
            _debtUsd = _debtUsd - _collateralUsd;
          }
        }
      }

      unchecked {
        ++_i;
      }
    }
  }

  // @todo - remove usage from test
  // @todo - move to calculator ??
  // @todo - pass current price here
  /// @notice Calculates the delta between average price and mark price, based on the size of position and whether the position is profitable.
  /// @param _size The size of the position.
  /// @param _isLong position direction
  /// @param _markPrice current market price
  /// @param _averagePrice The average price of the position.
  /// @return isProfit A boolean value indicating whether the position is profitable or not.
  /// @return delta The Profit between the average price and the fixed price, adjusted for the size of the order.
  function getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice
  ) public pure returns (bool, uint256) {
    // Check for invalid input: averagePrice cannot be zero.
    if (_averagePrice == 0) revert ITradeService_InvalidAveragePrice();

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

    // Return the values of isProfit and delta.
    return (isProfit, delta);
  }

  /**
   * Internal functions
   */

  // @todo - add description
  function _getSubAccount(address _primary, uint256 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  // @todo - add description
  function _getPositionId(address _account, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  /// @notice Calculates the next average price of a position, given the current position details and the next price.
  /// @param _size The current size of the position.
  /// @param _isLong Whether the position is long or short.
  /// @param _sizeDelta The size difference between the current position and the next position.
  /// @param _markPrice current market price
  /// @param _averagePrice The current average price of the position.
  /// @return The next average price of the position.
  function _getPositionNextAveragePrice(
    uint256 _size,
    bool _isLong,
    uint256 _sizeDelta,
    uint256 _markPrice,
    uint256 _averagePrice
  ) internal pure returns (uint256) {
    // Get the delta and isProfit value from the getDelta function
    (bool isProfit, uint256 delta) = getDelta(_size, _isLong, _markPrice, _averagePrice);
    // Calculate the next size and divisor
    uint256 nextSize = _size + _sizeDelta;
    uint256 divisor;
    if (_isLong) {
      divisor = isProfit ? nextSize + delta : nextSize - delta;
    } else {
      divisor = isProfit ? nextSize - delta : nextSize + delta;
    }

    // Calculate the next average price of the position
    return (_markPrice * nextSize) / divisor;
  }

  /// @notice This function increases the reserve value
  /// @param _assetClassIndex The index of asset class.
  /// @param _reservedValue The amount by which to increase the reserve value.
  function increaseReserved(uint256 _assetClassIndex, uint256 _reservedValue) internal {
    // Get the total TVL
    uint256 tvl = ICalculator(IConfigStorage(configStorage).calculator()).getPLPValueE30(true);

    // Retrieve the global state
    IPerpStorage.GlobalState memory _globalState = IPerpStorage(perpStorage).getGlobalState();

    // Retrieve the global asset class
    IPerpStorage.GlobalAssetClass memory _globalAssetClass = IPerpStorage(perpStorage).getGlobalAssetClassByIndex(
      _assetClassIndex
    );

    // get the liquidity configuration
    IConfigStorage.LiquidityConfig memory _liquidityConfig = IConfigStorage(configStorage).getLiquidityConfig();

    // Increase the reserve value by adding the reservedValue
    _globalState.reserveValueE30 += _reservedValue;
    _globalAssetClass.reserveValueE30 += _reservedValue;

    // Check if the new reserve value exceeds the % of AUM, and revert if it does
    if ((tvl * _liquidityConfig.maxPLPUtilization) < _globalState.reserveValueE30 * 1e18) {
      revert ITradeService_InsufficientLiquidity();
    }

    // Update the new reserve value in the IPerpStorage contract
    IPerpStorage(perpStorage).updateGlobalState(_globalState);
    IPerpStorage(perpStorage).updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
  }

  function abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  /// @notice health check for sub account that equity > margin maintenance required
  /// @param _subAccount target sub account for health check
  function _subAccountHealthCheck(address _subAccount) internal {
    ICalculator _calculator = ICalculator(IConfigStorage(configStorage).calculator());
    // check sub account is healthy
    uint256 _subAccountEquity = _calculator.getEquity(_subAccount);
    // maintenance margin requirement (MMR) = position size * maintenance margin fraction
    // note: maintenanceMarginFraction is 1e18
    uint256 _mmr = _calculator.getMMR(_subAccount);

    // if sub account equity < MMR, then trader couldn't decrease position
    if (_subAccountEquity < _mmr) revert ITradeService_SubAccountEquityIsUnderMMR();
  }

  /// @notice This function updates the borrowing rate for the given asset class index.
  /// @param _assetClassIndex The index of the asset class.
  function updateBorrowingRate(uint256 _assetClassIndex) public {
    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    IPerpStorage.GlobalAssetClass memory _globalAssetClass = IPerpStorage(perpStorage).getGlobalAssetClassByIndex(
      _assetClassIndex
    );
    uint256 _fundingInterval = IConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastBorrowingTime = _globalAssetClass.lastBorrowingTime;

    // If last borrowing time is 0, set it to the nearest funding interval time and return.
    if (_lastBorrowingTime == 0) {
      _globalAssetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      IPerpStorage(perpStorage).updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastBorrowingTime + _fundingInterval <= block.timestamp) {
      // update borrowing rate
      uint256 borrowingRate = getNextBorrowingRate(_assetClassIndex);
      _globalAssetClass.sumBorrowingRate += borrowingRate;
      _globalAssetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
    }
    IPerpStorage(perpStorage).updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
  }

  /// @notice This function updates the funding rate for the given market index.
  /// @param _marketIndex The index of the market.
  function updateFundingRate(uint256 _marketIndex) public {
    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(_marketIndex);

    uint256 _fundingInterval = IConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastFundingTime = _globalMarket.lastFundingTime;

    // If last funding time is 0, set it to the nearest funding interval time and return.
    if (_lastFundingTime == 0) {
      _globalMarket.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      IPerpStorage(perpStorage).updateGlobalMarket(_marketIndex, _globalMarket);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastFundingTime + _fundingInterval <= block.timestamp) {
      // update funding rate
      (int256 newFundingRate, int256 nextFundingRateLong, int256 nextFundingRateShort) = getNextFundingRate(
        _marketIndex
      );

      _globalMarket.currentFundingRate = newFundingRate;
      _globalMarket.accumFundingLong += nextFundingRateLong;
      _globalMarket.accumFundingShort += nextFundingRateShort;
      _globalMarket.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;

      IPerpStorage(perpStorage).updateGlobalMarket(_marketIndex, _globalMarket);
    }
  }

  /// @notice This function takes an asset class index as input and returns the next borrowing rate for that asset class.
  /// @param _assetClassIndex The index of the asset class.
  /// @return _nextBorrowingRate The next borrowing rate for the asset class.
  function getNextBorrowingRate(uint256 _assetClassIndex) public view returns (uint256 _nextBorrowingRate) {
    // Get the trading config, asset class config, and global asset class for the given asset class index.
    IConfigStorage.TradingConfig memory _tradingConfig = IConfigStorage(configStorage).getTradingConfig();
    IConfigStorage.AssetClassConfig memory _assetClassConfig = IConfigStorage(configStorage).getAssetClassConfigByIndex(
      _assetClassIndex
    );
    IPerpStorage.GlobalAssetClass memory _globalAssetClass = IPerpStorage(perpStorage).getGlobalAssetClassByIndex(
      _assetClassIndex
    );
    // Get the calculator.
    ICalculator _calculator = ICalculator(IConfigStorage(configStorage).calculator());
    // Get the PLP TVL.
    uint256 plpTVL = _calculator.getPLPValueE30(false); // TODO: make sure to use price

    // If block.timestamp not pass the next funding time, return 0.
    if (_globalAssetClass.lastBorrowingTime + _tradingConfig.fundingInterval > block.timestamp) return 0;
    // If PLP TVL is 0, return 0.
    if (plpTVL == 0) return 0;

    // Calculate the number of funding intervals that have passed since the last borrowing time.
    uint256 intervals = (block.timestamp - _globalAssetClass.lastBorrowingTime) / _tradingConfig.fundingInterval;

    // Calculate the next borrowing rate based on the asset class config, global asset class reserve value, and intervals.
    return (_assetClassConfig.baseBorrowingRate * _globalAssetClass.reserveValueE30 * intervals) / plpTVL;
  }

  /// @notice Calculates the borrowing fee for a given asset class based on the reserved value, entry borrowing rate, and current sum borrowing rate of the asset class.
  /// @param _assetClassIndex The index of the asset class for which to calculate the borrowing fee.
  /// @param _reservedValue The reserved value of the asset class.
  /// @param _entryBorrowingRate The entry borrowing rate of the asset class.
  /// @return borrowingFee The calculated borrowing fee for the asset class.
  function getBorrowingFee(
    uint256 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _entryBorrowingRate
  ) public view returns (uint256 borrowingFee) {
    // Get the global asset class.
    IPerpStorage.GlobalAssetClass memory _globalAssetClass = IPerpStorage(perpStorage).getGlobalAssetClassByIndex(
      _assetClassIndex
    );
    // Calculate borrowing rate.
    uint256 _borrowingRate = _globalAssetClass.sumBorrowingRate - _entryBorrowingRate;
    // Calculate the borrowing fee based on reserved value, borrowing rate.
    return (_reservedValue * _borrowingRate) / 1e18;
  }

  /// @notice Calculates the trading fee for a given position
  /// @param absSizeDelta Position size
  /// @param positionFeeRate Position Fee
  /// @return tradingFee The calculated trading fee for the position.
  function getTradingFee(uint256 absSizeDelta, uint256 positionFeeRate) public pure returns (uint256 tradingFee) {
    if (absSizeDelta == 0) return 0;
    return (absSizeDelta * positionFeeRate) / 1e18;
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
  ) public view returns (int256 fundingFee) {
    if (_size == 0) return 0;
    uint256 absSize = _size > 0 ? uint(_size) : uint(-_size);

    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(_marketIndex);

    int256 _fundingRate = _globalMarket.currentFundingRate - _entryFundingRate;

    // IF _fundingRate < 0, LONG positions pay fees to SHORT and SHORT positions receive fees from LONG
    // IF _fundingRate > 0, LONG positions receive fees from SHORT and SHORT pay fees to LONG
    fundingFee = (int(absSize) * _fundingRate) / 1e18;
    if (_isLong) {
      return _fundingRate < 0 ? -fundingFee : fundingFee;
    } else {
      return _fundingRate < 0 ? fundingFee : -fundingFee;
    }
  }

  /// @notice Calculate next funding rate using when increase/decrease position.
  /// @param marketIndex Market Index.
  /// @return fundingRate next funding rate using for both LONG & SHORT positions.
  /// @return fundingRateLong next funding rate for LONG.
  /// @return fundingRateShort next funding rate for SHORT.
  function getNextFundingRate(
    uint256 marketIndex
  ) public view returns (int256 fundingRate, int256 fundingRateLong, int256 fundingRateShort) {
    GetFundingRateVar memory vars;
    IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(configStorage).getMarketConfigByIndex(marketIndex);
    IPerpStorage.GlobalMarket memory globalMarket = IPerpStorage(perpStorage).getGlobalMarketByIndex(marketIndex);

    if (marketConfig.fundingRate.maxFundingRate == 0 || marketConfig.fundingRate.maxSkewScaleUSD == 0) return (0, 0, 0);

    // Get funding interval
    vars.fundingInterval = IConfigStorage(configStorage).getTradingConfig().fundingInterval;

    // If block.timestamp not pass the next funding time, return 0.
    if (globalMarket.lastFundingTime + vars.fundingInterval > block.timestamp) return (0, 0, 0);

    //@todo - validate timestamp of these
    (vars.marketPriceE30, ) = IOracleMiddleware(IConfigStorage(configStorage).oracle()).unsafeGetLatestPrice(
      marketConfig.assetId,
      false,
      marketConfig.priceConfidentThreshold
    );

    vars.marketSkewUSDE30 =
      ((int(globalMarket.longOpenInterest) - int(globalMarket.shortOpenInterest)) * int(vars.marketPriceE30)) /
      int(10 ** marketConfig.exponent);

    // The result of this nextFundingRate Formula will be in the range of [-maxFundingRate, maxFundingRate]
    vars.ratio = _max(-1e18, -((vars.marketSkewUSDE30 * 1e18) / int(marketConfig.fundingRate.maxSkewScaleUSD)));
    vars.ratio = _min(vars.ratio, 1e18);

    vars.nextFundingRate = (vars.ratio * int(marketConfig.fundingRate.maxFundingRate)) / 1e18;

    vars.newFundingRate = globalMarket.currentFundingRate + vars.nextFundingRate;

    vars.elapsedIntervals = int((block.timestamp - globalMarket.lastFundingTime) / vars.fundingInterval);

    if (globalMarket.longOpenInterest > 0) {
      fundingRateLong = (vars.newFundingRate * int(globalMarket.longPositionSize) * vars.elapsedIntervals) / 1e30;
    }
    if (globalMarket.shortOpenInterest > 0) {
      fundingRateShort = (vars.newFundingRate * -int(globalMarket.shortPositionSize) * vars.elapsedIntervals) / 1e30;
    }

    return (vars.newFundingRate, fundingRateLong, fundingRateShort);
  }

  /// @notice This function collects margin fee from position
  /// @param _subAccount The sub-account from which to collect the fee.
  /// @param _absSizeDelta Position size to be increased or decreased in absolute value
  /// @param _assetClassIndex The index of the asset class for which to calculate the borrowing fee.
  /// @param _reservedValue The reserved value of the asset class.
  /// @param _entryBorrowingRate The entry borrowing rate of the asset class.
  function collectMarginFee(
    address _subAccount,
    uint256 _absSizeDelta,
    uint256 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _entryBorrowingRate,
    uint256 _positionFee
  ) public {
    // Get the debt fee of the sub-account
    int256 feeUsd = IPerpStorage(perpStorage).getSubAccountFee(_subAccount);

    // Calculate trading Fee USD
    uint256 tradingFeeUsd = getTradingFee(_absSizeDelta, _positionFee);
    feeUsd += int(tradingFeeUsd);

    emit LogCollectTradingFee(_subAccount, _assetClassIndex, tradingFeeUsd);

    // Calculate the borrowing fee
    uint256 borrowingFee = getBorrowingFee(_assetClassIndex, _reservedValue, _entryBorrowingRate);
    feeUsd += int(borrowingFee);

    emit LogCollectBorrowingFee(_subAccount, _assetClassIndex, borrowingFee);

    // Update the sub-account's debt fee balance
    IPerpStorage(perpStorage).updateSubAccountFee(_subAccount, feeUsd);
  }

  /// @notice This function collects funding fee from position.
  /// @param _subAccount The sub-account from which to collect the fee.
  /// @param _assetClassIndex Index of the asset class associated with the market.
  /// @param _marketIndex Index of the market to collect funding fee from.
  /// @param _positionSizeE30 Size of position in units of 10^-30 of the underlying asset.
  /// @param _entryFundingRate The borrowing rate at the time the position was opened.
  function collectFundingFee(
    address _subAccount,
    uint256 _assetClassIndex,
    uint256 _marketIndex,
    int256 _positionSizeE30,
    int256 _entryFundingRate
  ) public {
    // Get the debt fee of the sub-account
    int256 feeUsd = IPerpStorage(perpStorage).getSubAccountFee(_subAccount);

    // Calculate the borrowing fee
    bool isLong = _positionSizeE30 > 0;

    int256 fundingFee = getFundingFee(_marketIndex, isLong, _positionSizeE30, _entryFundingRate);
    feeUsd += fundingFee;

    emit LogCollectFundingFee(_subAccount, _assetClassIndex, fundingFee);

    // Update the sub-account's debt fee balance
    IPerpStorage(perpStorage).updateSubAccountFee(_subAccount, feeUsd);
  }

  /// @notice This function settle margin fee from trader's sub-account
  /// @param _subAccount The sub-account from which to collect the fee.
  function settleMarginFee(address _subAccount) public {
    SettleMarginFeeVar memory acmVars;
    address _vaultStorage = vaultStorage;
    address _perpStorage = perpStorage;
    address _configStorage = configStorage;

    // Retrieve the debt fee amount for the sub-account
    acmVars.feeUsd = IPerpStorage(_perpStorage).getSubAccountFee(_subAccount);

    // If there's no fee that trader need to pay more, return early
    if (acmVars.feeUsd <= 0) return;
    acmVars.absFeeUsd = acmVars.feeUsd > 0 ? uint256(acmVars.feeUsd) : uint256(-acmVars.feeUsd);

    IConfigStorage.TradingConfig memory _tradingConfig = IConfigStorage(_configStorage).getTradingConfig();
    IOracleMiddleware oracle = IOracleMiddleware(IConfigStorage(configStorage).oracle());
    acmVars.plpUnderlyingTokens = IConfigStorage(configStorage).getPlpTokens();

    // Loop through all the plp underlying tokens for the sub-account to pay trading fees
    for (uint256 i = 0; i < acmVars.plpUnderlyingTokens.length; ) {
      SettleMarginFeeLoopVar memory tmpVars; // This will be re-assigned every times when start looping
      tmpVars.underlyingToken = acmVars.plpUnderlyingTokens[i];
      tmpVars.underlyingTokenDecimal = ERC20(tmpVars.underlyingToken).decimals();
      tmpVars.traderBalance = IVaultStorage(_vaultStorage).traderBalances(_subAccount, tmpVars.underlyingToken);

      // If the sub-account has a balance of this underlying token (collateral token amount)
      if (tmpVars.traderBalance > 0) {
        // Retrieve the latest price and confident threshold of the plp underlying token
        (tmpVars.price, ) = oracle.getLatestPrice(
          tmpVars.underlyingToken.toBytes32(),
          false,
          IConfigStorage(_configStorage).getMarketConfigByToken(tmpVars.underlyingToken).priceConfidentThreshold,
          30
        );

        tmpVars.feeTokenAmount = (acmVars.absFeeUsd * (10 ** tmpVars.underlyingTokenDecimal)) / tmpVars.price;

        if (tmpVars.traderBalance > tmpVars.feeTokenAmount) {
          tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount;
          tmpVars.traderBalance -= tmpVars.feeTokenAmount;
          acmVars.absFeeUsd = 0;
        } else {
          tmpVars.traderBalanceValue = (tmpVars.traderBalance * tmpVars.price) / (10 ** tmpVars.underlyingTokenDecimal);
          tmpVars.repayFeeTokenAmount = tmpVars.traderBalance;
          tmpVars.traderBalance = 0;
          acmVars.absFeeUsd -= tmpVars.traderBalanceValue;
        }

        // Calculate the developer fee amount in the plp underlying token
        tmpVars.devFeeTokenAmount = (tmpVars.repayFeeTokenAmount * _tradingConfig.devFeeRate) / 1e18;
        // Deducts for dev fee
        tmpVars.repayFeeTokenAmount -= tmpVars.devFeeTokenAmount;

        IVaultStorage(_vaultStorage).collectMarginFee(
          _subAccount,
          tmpVars.underlyingToken,
          tmpVars.repayFeeTokenAmount,
          tmpVars.devFeeTokenAmount,
          tmpVars.traderBalance
        );
      }

      // If no remaining trading fee to pay then stop looping
      if (acmVars.absFeeUsd == 0) break;

      unchecked {
        ++i;
      }
    }

    IPerpStorage(_perpStorage).updateSubAccountFee(_subAccount, int(acmVars.absFeeUsd));
  }

  /// @notice Settles the fees for a given sub-account.
  /// @param _subAccount The address of the sub-account to settle fees for.
  function settleFundingFee(address _subAccount) public {
    SettleFundingFeeVar memory acmVars;
    address _vaultStorage = vaultStorage;
    address _perpStorage = perpStorage;
    address _configStorage = configStorage;

    // Retrieve the debt fee amount for the sub-account
    acmVars.feeUsd = IPerpStorage(_perpStorage).getSubAccountFee(_subAccount);

    // If there's no fee to settle, return early
    if (acmVars.feeUsd == 0) return;

    bool isPayFee = acmVars.feeUsd > 0; // feeUSD > 0 means trader pays fee, feeUSD < 0 means trader gets fee
    acmVars.absFeeUsd = acmVars.feeUsd > 0 ? uint256(acmVars.feeUsd) : uint256(-acmVars.feeUsd);

    IOracleMiddleware oracle = IOracleMiddleware(IConfigStorage(_configStorage).oracle());
    acmVars.plpUnderlyingTokens = IConfigStorage(_configStorage).getPlpTokens();
    acmVars.plpLiquidityDebtUSDE30 = IVaultStorage(_vaultStorage).plpLiquidityDebtUSDE30(); // Global funding debts that borrowing from PLP

    // Loop through all the plp underlying tokens for the sub-account to receive or pay funding fees
    for (uint256 i = 0; i < acmVars.plpUnderlyingTokens.length; ) {
      SettleFundingFeeLoopVar memory tmpVars;
      tmpVars.underlyingToken = acmVars.plpUnderlyingTokens[i];

      tmpVars.underlyingTokenDecimal = ERC20(tmpVars.underlyingToken).decimals();

      // Retrieve the balance of each plp underlying token for the sub-account (token collateral amount)
      tmpVars.traderBalance = IVaultStorage(_vaultStorage).traderBalances(_subAccount, tmpVars.underlyingToken);
      tmpVars.fundingFee = IVaultStorage(_vaultStorage).fundingFee(tmpVars.underlyingToken); // Global token amount of funding fee collected from traders

      // Retrieve the latest price and confident threshold of the plp underlying token
      (tmpVars.price, ) = oracle.getLatestPrice(
        tmpVars.underlyingToken.toBytes32(),
        false,
        IConfigStorage(_configStorage).getMarketConfigByToken(tmpVars.underlyingToken).priceConfidentThreshold,
        30
      );

      // feeUSD > 0 or isPayFee == true, means trader pay fee
      if (isPayFee) {
        // If the sub-account has a balance of this underlying token (collateral token amount)
        if (tmpVars.traderBalance != 0) {
          // If this plp underlying token contains borrowing debt from PLP then trader must repays debt to PLP first
          if (acmVars.plpLiquidityDebtUSDE30 > 0) _repayFundingFeeDebtToPLP(_subAccount, acmVars, tmpVars);
          // If there are any remaining absFeeUsd, the trader must continue repaying the debt until the full amount is paid off
          if (tmpVars.traderBalance != 0 && acmVars.absFeeUsd > 0) _payFundingFee(_subAccount, acmVars, tmpVars);
        }
      }
      // feeUSD < 0 or isPayFee == false, means trader receive fee
      else {
        if (tmpVars.fundingFee != 0) {
          _receiveFundingFee(_subAccount, acmVars, tmpVars);
        }
      }

      // If no remaining margin fee to receive or repay then stop looping
      if (acmVars.absFeeUsd == 0) break;

      {
        unchecked {
          ++i;
        }
      }
    }

    // If a trader is supposed to receive a fee but the amount of tokens received from funding fees is not sufficient to cover the fee,
    // then the protocol must provide the option to borrow in USD and record the resulting debt on the plpLiquidityDebtUSDE30 log
    if (!isPayFee && acmVars.absFeeUsd > 0) {
      _borrowFundingFeeFromPLP(_subAccount, oracle, acmVars);
    }

    // Update the fee amount for the sub-account in the PerpStorage contract

    IPerpStorage(_perpStorage).updateSubAccountFee(_subAccount, int(acmVars.absFeeUsd));
  }

  /// @notice get next short average price with realized PNL
  /// @param _market - global market
  /// @param _currentPrice - min / max price depends on position direction
  /// @param _positionSizeDelta - position size after increase / decrease.
  ///                           if positive is LONG position, else is SHORT
  /// @param _realizedPositionPnl - position realized PnL if positive is profit, and negative is loss
  /// @return _nextAveragePrice next average price
  function _calculateShortAveragePrice(
    IPerpStorage.GlobalMarket memory _market,
    uint256 _currentPrice,
    int256 _positionSizeDelta,
    int256 _realizedPositionPnl
  ) internal pure returns (uint256 _nextAveragePrice) {
    // global
    uint256 _globalPositionSize = _market.shortPositionSize;
    int256 _globalAveragePrice = int256(_market.shortAvgPrice);

    if (_globalAveragePrice == 0) return 0;

    // if positive means, has profit
    int256 _globalPnl = (int256(_globalPositionSize) * (_globalAveragePrice - int256(_currentPrice))) /
      _globalAveragePrice;
    int256 _newGlobalPnl = _globalPnl - _realizedPositionPnl;

    uint256 _newGlobalPositionSize;
    // position > 0 is means decrease short position
    // else is increase short position
    if (_positionSizeDelta > 0) {
      _newGlobalPositionSize = _globalPositionSize - uint256(_positionSizeDelta);
    } else {
      _newGlobalPositionSize = _globalPositionSize + uint256(-_positionSizeDelta);
    }

    bool _isGlobalProfit = _newGlobalPnl > 0;
    uint256 _absoluteGlobalPnl = uint256(_isGlobalProfit ? _newGlobalPnl : -_newGlobalPnl);

    // divisor = latest global position size - pnl
    uint256 divisor = _isGlobalProfit
      ? (_newGlobalPositionSize - _absoluteGlobalPnl)
      : (_newGlobalPositionSize + _absoluteGlobalPnl);

    if (divisor == 0) return 0;

    // next short average price = current price * latest global position size / latest global position size - pnl
    _nextAveragePrice = (_currentPrice * _newGlobalPositionSize) / divisor;

    return _nextAveragePrice;
  }

  /// @notice get next long average price with realized PNL
  /// @param _market - global market
  /// @param _currentPrice - min / max price depends on position direction
  /// @param _positionSizeDelta - position size after increase / decrease.
  ///                           if positive is LONG position, else is SHORT
  /// @param _realizedPositionPnl - position realized PnL if positive is profit, and negative is loss
  /// @return _nextAveragePrice next average price
  function _calculateLongAveragePrice(
    IPerpStorage.GlobalMarket memory _market,
    uint256 _currentPrice,
    int256 _positionSizeDelta,
    int256 _realizedPositionPnl
  ) internal pure returns (uint256 _nextAveragePrice) {
    // global
    uint256 _globalPositionSize = _market.longPositionSize;
    int256 _globalAveragePrice = int256(_market.longAvgPrice);

    if (_globalAveragePrice == 0) return 0;

    // if positive means, has profit
    int256 _globalPnl = (int256(_globalPositionSize) * (int256(_currentPrice) - _globalAveragePrice)) /
      _globalAveragePrice;
    int256 _newGlobalPnl = _globalPnl - _realizedPositionPnl;

    uint256 _newGlobalPositionSize;
    // position > 0 is means increase short position
    // else is decrease short position
    if (_positionSizeDelta > 0) {
      _newGlobalPositionSize = _globalPositionSize + uint256(_positionSizeDelta);
    } else {
      _newGlobalPositionSize = _globalPositionSize - uint256(-_positionSizeDelta);
    }

    bool _isGlobalProfit = _newGlobalPnl > 0;
    uint256 _absoluteGlobalPnl = uint256(_isGlobalProfit ? _newGlobalPnl : -_newGlobalPnl);

    // divisor = latest global position size + pnl
    uint256 divisor = _isGlobalProfit
      ? (_newGlobalPositionSize + _absoluteGlobalPnl)
      : (_newGlobalPositionSize - _absoluteGlobalPnl);

    if (divisor == 0) return 0;

    // next long average price = current price * latest global position size / latest global position size + pnl
    _nextAveragePrice = (_currentPrice * _newGlobalPositionSize) / divisor;

    return _nextAveragePrice;
  }

  function _payFundingFee(
    address subAccount,
    SettleFundingFeeVar memory acmVars,
    SettleFundingFeeLoopVar memory tmpVars
  ) internal {
    address _vaultStorage = vaultStorage;

    // Calculate the fee amount in the plp underlying token
    tmpVars.feeTokenAmount = (acmVars.absFeeUsd * (10 ** tmpVars.underlyingTokenDecimal)) / tmpVars.price;

    // Repay the fee amount and subtract it from the balance
    tmpVars.repayFeeTokenAmount = 0;

    if (tmpVars.traderBalance > tmpVars.feeTokenAmount) {
      tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount;
      tmpVars.traderBalance -= tmpVars.feeTokenAmount;
      acmVars.absFeeUsd = 0;
    } else {
      // Calculate the balance value of the plp underlying token in USD
      tmpVars.traderBalanceValue = (tmpVars.traderBalance * tmpVars.price) / (10 ** tmpVars.underlyingTokenDecimal);

      tmpVars.repayFeeTokenAmount = tmpVars.traderBalance;
      tmpVars.traderBalance = 0;
      acmVars.absFeeUsd -= tmpVars.traderBalanceValue;
    }

    IVaultStorage(_vaultStorage).collectFundingFee(
      subAccount,
      tmpVars.underlyingToken,
      tmpVars.repayFeeTokenAmount,
      tmpVars.traderBalance
    );
  }

  function _receiveFundingFee(
    address subAccount,
    SettleFundingFeeVar memory acmVars,
    SettleFundingFeeLoopVar memory tmpVars
  ) internal {
    address _vaultStorage = vaultStorage;

    // Calculate the fee amount in the plp underlying token
    tmpVars.feeTokenAmount = (acmVars.absFeeUsd * (10 ** tmpVars.underlyingTokenDecimal)) / tmpVars.price;

    if (tmpVars.fundingFee > tmpVars.feeTokenAmount) {
      // funding fee token has enough amount to repay fee to trader
      tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount;
      tmpVars.traderBalance += tmpVars.feeTokenAmount;
      acmVars.absFeeUsd = 0;
    } else {
      // funding fee token has not enough amount to repay fee to trader
      // Calculate the funding Fee value of the plp underlying token in USD
      tmpVars.fundingFeeValue = (tmpVars.fundingFee * tmpVars.price) / (10 ** tmpVars.underlyingTokenDecimal);

      tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount;
      tmpVars.traderBalance += tmpVars.feeTokenAmount;
      acmVars.absFeeUsd -= tmpVars.fundingFeeValue;
    }

    IVaultStorage(_vaultStorage).repayFundingFee(
      subAccount,
      tmpVars.underlyingToken,
      tmpVars.repayFeeTokenAmount,
      tmpVars.traderBalance
    );
  }

  function _borrowFundingFeeFromPLP(
    address subAccount,
    IOracleMiddleware oracle,
    SettleFundingFeeVar memory acmVars
  ) internal {
    address _vaultStorage = vaultStorage;
    // Loop through all the plp underlying tokens for the sub-account
    for (uint256 i = 0; i < acmVars.plpUnderlyingTokens.length; ) {
      SettleFundingFeeLoopVar memory tmpVars;
      tmpVars.underlyingToken = acmVars.plpUnderlyingTokens[i];

      tmpVars.underlyingTokenDecimal = ERC20(tmpVars.underlyingToken).decimals();
      uint256 plpLiquidityAmount = IVaultStorage(_vaultStorage).plpLiquidity(tmpVars.underlyingToken);

      // Retrieve the latest price and confident threshold of the plp underlying token
      (tmpVars.price, ) = oracle.getLatestPrice(
        tmpVars.underlyingToken.toBytes32(),
        false,
        IConfigStorage(configStorage).getMarketConfigByToken(tmpVars.underlyingToken).priceConfidentThreshold,
        30
      );

      // Calculate the fee amount in the plp underlying token
      tmpVars.feeTokenAmount = (acmVars.absFeeUsd * (10 ** tmpVars.underlyingTokenDecimal)) / tmpVars.price;

      uint256 borrowPlpLiquidityValue;
      if (plpLiquidityAmount > tmpVars.feeTokenAmount) {
        // plp underlying token has enough amount to repay fee to trader
        borrowPlpLiquidityValue = acmVars.absFeeUsd;
        tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount;
        tmpVars.traderBalance += tmpVars.feeTokenAmount;

        acmVars.absFeeUsd = 0;
      } else {
        // plp underlying token has not enough amount to repay fee to trader
        // Calculate the plpLiquidityAmount value of the plp underlying token in USD
        borrowPlpLiquidityValue = (plpLiquidityAmount * tmpVars.price) / (10 ** tmpVars.underlyingTokenDecimal);
        tmpVars.repayFeeTokenAmount = plpLiquidityAmount;
        tmpVars.traderBalance += plpLiquidityAmount;
        acmVars.absFeeUsd -= borrowPlpLiquidityValue;
      }

      IVaultStorage(_vaultStorage).borrowFundingFeeFromPLP(
        subAccount,
        tmpVars.underlyingToken,
        tmpVars.repayFeeTokenAmount,
        borrowPlpLiquidityValue,
        tmpVars.traderBalance
      );

      if (acmVars.absFeeUsd == 0) {
        break;
      }

      {
        unchecked {
          ++i;
        }
      }
    }
  }

  /// @notice Repay funding fee to PLP
  /// @param subAccount - Trader's sub-account to repay fee
  /// @param acmVars - Accumulative struct variable
  /// @param tmpVars - Temporary struct variable
  function _repayFundingFeeDebtToPLP(
    address subAccount,
    SettleFundingFeeVar memory acmVars,
    SettleFundingFeeLoopVar memory tmpVars
  ) internal {
    address _vaultStorage = vaultStorage;

    // Calculate the sub-account's fee debt to token amounts
    tmpVars.feeTokenAmount = (acmVars.absFeeUsd * (10 ** tmpVars.underlyingTokenDecimal)) / tmpVars.price;

    // Calculate the debt in USD to plp underlying token amounts
    uint256 plpLiquidityDebtAmount = (acmVars.plpLiquidityDebtUSDE30 * (10 ** tmpVars.underlyingTokenDecimal)) /
      tmpVars.price;
    uint256 traderBalanceValueE30 = (tmpVars.traderBalance * tmpVars.price) / (10 ** tmpVars.underlyingTokenDecimal);

    if (tmpVars.feeTokenAmount >= plpLiquidityDebtAmount) {
      // If margin fee to repay is grater than debt on PLP (Rare case)
      if (tmpVars.traderBalance > tmpVars.feeTokenAmount) {
        // If trader has enough token amounts to repay fee to PLP
        tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount; // Amount of feeTokenAmount that PLP will receive
        tmpVars.traderBalance -= tmpVars.feeTokenAmount; // Deducts all feeTokenAmount to repay to PLP
        tmpVars.feeTokenValue = acmVars.plpLiquidityDebtUSDE30; // USD value of feeTokenAmount that PLP will receive
        acmVars.absFeeUsd -= acmVars.plpLiquidityDebtUSDE30; // Deducts margin fee on trader's sub-account
      } else {
        tmpVars.repayFeeTokenAmount = tmpVars.traderBalance; // Amount of feeTokenAmount that PLP will receive
        tmpVars.traderBalance = 0; // Deducts all feeTokenAmount to repay to PLP
        tmpVars.feeTokenValue = acmVars.plpLiquidityDebtUSDE30; // USD value of feeTokenAmount that PLP will receive
        acmVars.absFeeUsd -= traderBalanceValueE30; // Deducts margin fee on trader's sub-account
      }
    } else if (tmpVars.feeTokenAmount < plpLiquidityDebtAmount) {
      if (tmpVars.traderBalance >= tmpVars.feeTokenAmount) {
        traderBalanceValueE30 =
          ((tmpVars.traderBalance - tmpVars.feeTokenAmount) * tmpVars.price) /
          (10 ** tmpVars.underlyingTokenDecimal);

        tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount; // Trader will repay fee with this token amounts they have
        tmpVars.traderBalance -= tmpVars.feeTokenAmount; // Deducts repay token amounts from trader account
        tmpVars.feeTokenValue = traderBalanceValueE30; // USD value of token amounts that PLP will receive
        acmVars.absFeeUsd -= traderBalanceValueE30; // Deducts margin fee on trader's sub-account
      } else {
        tmpVars.repayFeeTokenAmount = tmpVars.traderBalance; // Trader will repay fee with this token amounts they have
        tmpVars.traderBalance = 0; // Deducts repay token amounts from trader account
        tmpVars.feeTokenValue = traderBalanceValueE30; // USD value of token amounts that PLP will receive
        acmVars.absFeeUsd -= traderBalanceValueE30; // Deducts margin fee on trader's sub-account
      }
    }

    IVaultStorage(_vaultStorage).repayFundingFeeToPLP(
      subAccount,
      tmpVars.underlyingToken,
      tmpVars.repayFeeTokenAmount,
      tmpVars.feeTokenValue,
      tmpVars.traderBalance
    );
  }

  function _max(int256 a, int256 b) internal pure returns (int256) {
    return a > b ? a : b;
  }

  function _min(int256 a, int256 b) internal pure returns (int256) {
    return a < b ? a : b;
  }
}
