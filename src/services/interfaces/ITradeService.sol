// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITradeService {
  /**
   * Errors
   */
  error ITradeService_MarketIsDelisted();
  error ITradeService_MarketIsClosed();
  error ITradeService_PositionAlreadyClosed();
  error ITradeService_DecreaseTooHighPositionSize();
  error ITradeService_SubAccountEquityIsUnderMMR();
  error ITradeService_TooTinyPosition();
  error ITradeService_BadSubAccountId();
  error ITradeService_BadSizeDelta();
  error ITradeService_NotAllowIncrease();
  error ITradeService_BadNumberOfPosition();
  error ITradeService_BadExposure();
  error ITradeService_InvalidAveragePrice();
  error ITradeService_BadPositionSize();
  error ITradeService_InsufficientLiquidity();
  error ITradeService_InsufficientFreeCollateral();
  error ITradeService_NotPositionOwner();
  error ITradeService_ReservedValueStillEnough();

  /**
   * STRUCTS
   */

  struct GetFundingRateVar {
    uint256 fundingInterval;
    uint256 marketPriceE30;
    int256 marketSkewUSDE30;
    int256 ratio;
    int256 nextFundingRate;
    int256 newFundingRate;
    int256 elapsedIntervals;
  }

  struct SettleFeeVar {
    bool isPayFee;
    int256 feeUsd;
    uint256 absFeeUsd;
    uint256 plpLiquidityDebtUSDE30;
    address[] plpUnderlyingTokens;
    address underlyingToken;
    uint256 underlyingTokenDecimal;
    uint256 traderBalance;
    uint256 traderBalanceValue;
    uint256 marginFee;
    uint256 marginFeeValue;
    uint256 price;
    uint256 feeTokenAmount;
    uint256 feeTokenValue;
    uint256 repayFeeTokenAmount;
    uint256 devFeeTokenAmount;
  }

  function configStorage() external view returns (address);

  function perpStorage() external view returns (address);

  function increasePosition(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta
  ) external;

  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease,
    address _tpToken
  ) external;

  function forceClosePosition(address _account, uint256 _subAccountId, uint256 _marketIndex, address _tpToken) external;
}
