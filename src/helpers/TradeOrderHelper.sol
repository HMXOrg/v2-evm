// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { IntentHandler } from "@hmx/handlers/IntentHandler.sol";
import { TradeService } from "@hmx/services/TradeService.sol";

contract TradeOrderHelper is Ownable {
  error TradeOrderHelper_MaxTradeSize();
  error TradeOrderHelper_MaxPositionSize();
  error TradeOrderHelper_PriceSlippage();
  error TradeOrderHelper_MarketIsClosed();
  error TradeOrderHelper_InvalidPriceForExecution();
  error TradeOrderHelper_NotWhiteListed();
  error TradeOrderHelper_OrderStale();

  event LogSetLimit(uint256 _marketIndex, uint256 _positionSizeLimitOf, uint256 _tradeSizeLimitOf);

  ConfigStorage public configStorage;
  PerpStorage public perpStorage;
  OracleMiddleware public oracle;
  TradeService public tradeService;
  uint256 maxOrderAge;
  address whitelistedCaller;

  mapping(uint256 marketIndex => uint256 sizeLimit) public positionSizeLimitOf;
  mapping(uint256 marketIndex => uint256 sizeLimit) public tradeSizeLimitOf;

  struct ValidatePositionOrderPriceVars {
    ConfigStorage.MarketConfig marketConfig;
    OracleMiddleware oracle;
    PerpStorage.Market globalMarket;
    uint256 oraclePrice;
    uint256 adaptivePrice;
    uint8 marketStatus;
    bool isPriceValid;
  }

  constructor(address _configStorage, address _perpStorage, address _oracle, address _tradeService) {
    configStorage = ConfigStorage(_configStorage);
    perpStorage = PerpStorage(_perpStorage);
    oracle = OracleMiddleware(_oracle);
    tradeService = TradeService(_tradeService);
  }

  modifier onlyWhitelistedCaller() {
    if (msg.sender != whitelistedCaller) revert TradeOrderHelper_NotWhiteListed();
    _;
  }

  function _validate(
    address mainAccount,
    uint8 subAccountId,
    uint256 marketIndex,
    bool reduceOnly,
    int256 sizeDelta,
    bool triggerAboveThreshold,
    uint256 triggerPrice,
    uint256 acceptablePrice,
    uint256 createdTimestamp
  ) internal view {
    bool isMarketOrder = triggerAboveThreshold && triggerPrice == 0;
    if (isMarketOrder && createdTimestamp + maxOrderAge > block.timestamp) {
      revert TradeOrderHelper_OrderStale();
    }

    address _subAccount = HMXLib.getSubAccount(mainAccount, subAccountId);
    int256 _positionSizeE30 = perpStorage
      .getPositionById(HMXLib.getPositionId(_subAccount, marketIndex))
      .positionSizeE30;

    // Check trade size limit as per market
    if (tradeSizeLimitOf[marketIndex] > 0 && !reduceOnly && HMXLib.abs(sizeDelta) > tradeSizeLimitOf[marketIndex]) {
      revert TradeOrderHelper_MaxTradeSize();
    }

    // Check position size limit as per market
    if (
      positionSizeLimitOf[marketIndex] > 0 &&
      !reduceOnly &&
      HMXLib.abs(_positionSizeE30 + sizeDelta) > positionSizeLimitOf[marketIndex]
    ) {
      revert TradeOrderHelper_MaxPositionSize();
    }

    ValidatePositionOrderPriceVars memory vars;

    // SLOADs
    // Get price from Pyth
    vars.marketConfig = configStorage.getMarketConfigByIndex(marketIndex);
    vars.globalMarket = perpStorage.getMarketByIndex(marketIndex);

    // Validate trigger price with oracle price
    (vars.oraclePrice, ) = oracle.getLatestPrice(vars.marketConfig.assetId, true);
    vars.isPriceValid = triggerAboveThreshold ? vars.oraclePrice > triggerPrice : vars.oraclePrice < triggerPrice;

    if (!vars.isPriceValid) revert TradeOrderHelper_InvalidPriceForExecution();

    // Validate acceptable price with adaptive price
    (vars.adaptivePrice, , vars.marketStatus) = oracle.getLatestAdaptivePriceWithMarketStatus(
      vars.marketConfig.assetId,
      false,
      (int(vars.globalMarket.longPositionSize) - int(vars.globalMarket.shortPositionSize)),
      sizeDelta,
      vars.marketConfig.fundingRate.maxSkewScaleUSD,
      0
    );

    // Validate market status
    if (vars.marketStatus != 2) revert TradeOrderHelper_MarketIsClosed();

    // Validate price is executable
    bool isBuy = sizeDelta > 0;
    vars.isPriceValid = isBuy ? vars.adaptivePrice < acceptablePrice : vars.adaptivePrice > acceptablePrice;

    if (!vars.isPriceValid) revert TradeOrderHelper_PriceSlippage();
  }

  function execute(IntentHandler.ExecuteTradeOrderVars memory vars) external {
    _validate(
      vars.account,
      vars.subAccountId,
      vars.marketIndex,
      vars.reduceOnly,
      vars.sizeDelta,
      vars.triggerAboveThreshold,
      vars.triggerPrice,
      vars.acceptablePrice,
      vars.createdTimestamp
    );

    // Retrieve existing position
    vars.positionId = HMXLib.getPositionId(vars.subAccount, vars.marketIndex);
    PerpStorage.Position memory _existingPosition = PerpStorage(tradeService.perpStorage()).getPositionById(
      vars.positionId
    );

    // Execute the order
    if (vars.reduceOnly) {
      bool isDecreaseShort = (vars.sizeDelta > 0 && _existingPosition.positionSizeE30 < 0);
      bool isDecreaseLong = (vars.sizeDelta < 0 && _existingPosition.positionSizeE30 > 0);
      bool isClosePosition = !vars.isNewPosition && (isDecreaseShort || isDecreaseLong);
      if (isClosePosition) {
        tradeService.decreasePosition({
          _account: vars.account,
          _subAccountId: vars.subAccountId,
          _marketIndex: vars.marketIndex,
          _positionSizeE30ToDecrease: HMXLib.min(
            HMXLib.abs(vars.sizeDelta),
            HMXLib.abs(_existingPosition.positionSizeE30)
          ),
          _tpToken: vars.tpToken,
          _limitPriceE30: 0
        });
      } else {
        // Do nothing if the size delta is wrong for reduce-only
      }
    } else {
      if (vars.sizeDelta > 0) {
        // BUY
        if (vars.isNewPosition || vars.positionIsLong) {
          // New position and Long position
          // just increase position when BUY
          tradeService.increasePosition({
            _primaryAccount: vars.account,
            _subAccountId: vars.subAccountId,
            _marketIndex: vars.marketIndex,
            _sizeDelta: vars.sizeDelta,
            _limitPriceE30: 0
          });
        } else {
          bool _flipSide = vars.sizeDelta > (-_existingPosition.positionSizeE30);
          if (_flipSide) {
            // Flip the position
            // Fully close Short position
            tradeService.decreasePosition({
              _account: vars.account,
              _subAccountId: vars.subAccountId,
              _marketIndex: vars.marketIndex,
              _positionSizeE30ToDecrease: uint256(-_existingPosition.positionSizeE30),
              _tpToken: vars.tpToken,
              _limitPriceE30: 0
            });
            // Flip it to Long position
            tradeService.increasePosition({
              _primaryAccount: vars.account,
              _subAccountId: vars.subAccountId,
              _marketIndex: vars.marketIndex,
              _sizeDelta: vars.sizeDelta + _existingPosition.positionSizeE30,
              _limitPriceE30: 0
            });
          } else {
            // Not flip
            tradeService.decreasePosition({
              _account: vars.account,
              _subAccountId: vars.subAccountId,
              _marketIndex: vars.marketIndex,
              _positionSizeE30ToDecrease: uint256(vars.sizeDelta),
              _tpToken: vars.tpToken,
              _limitPriceE30: 0
            });
          }
        }
      } else if (vars.sizeDelta < 0) {
        // SELL
        if (vars.isNewPosition || !vars.positionIsLong) {
          // New position and Short position
          // just increase position when SELL
          tradeService.increasePosition({
            _primaryAccount: vars.account,
            _subAccountId: vars.subAccountId,
            _marketIndex: vars.marketIndex,
            _sizeDelta: vars.sizeDelta,
            _limitPriceE30: 0
          });
        } else if (vars.positionIsLong) {
          bool _flipSide = (-vars.sizeDelta) > _existingPosition.positionSizeE30;
          if (_flipSide) {
            // Flip the position
            // Fully close Long position
            tradeService.decreasePosition({
              _account: vars.account,
              _subAccountId: vars.subAccountId,
              _marketIndex: vars.marketIndex,
              _positionSizeE30ToDecrease: uint256(_existingPosition.positionSizeE30),
              _tpToken: vars.tpToken,
              _limitPriceE30: 0
            });
            // Flip it to Short position
            tradeService.increasePosition({
              _primaryAccount: vars.account,
              _subAccountId: vars.subAccountId,
              _marketIndex: vars.marketIndex,
              _sizeDelta: vars.sizeDelta + _existingPosition.positionSizeE30,
              _limitPriceE30: 0
            });
          } else {
            // Not flip
            tradeService.decreasePosition({
              _account: vars.account,
              _subAccountId: vars.subAccountId,
              _marketIndex: vars.marketIndex,
              _positionSizeE30ToDecrease: uint256(-vars.sizeDelta),
              _tpToken: vars.tpToken,
              _limitPriceE30: 0
            });
          }
        }
      }
    }
  }

  function setLimit(
    uint256[] calldata _marketIndexes,
    uint256[] calldata _positionSizeLimits,
    uint256[] calldata _tradeSizeLimits
  ) external onlyOwner {
    require(
      _marketIndexes.length == _positionSizeLimits.length && _positionSizeLimits.length == _tradeSizeLimits.length,
      "length not match"
    );
    uint256 _len = _marketIndexes.length;
    for (uint256 i = 0; i < _len; ) {
      positionSizeLimitOf[_marketIndexes[i]] = _positionSizeLimits[i];
      tradeSizeLimitOf[_marketIndexes[i]] = _tradeSizeLimits[i];

      emit LogSetLimit(_marketIndexes[i], _positionSizeLimits[i], _tradeSizeLimits[i]);

      unchecked {
        ++i;
      }
    }
  }
}
