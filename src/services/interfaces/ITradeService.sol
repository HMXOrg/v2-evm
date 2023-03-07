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
  error ITradeService_ReservedValueStillEnough();

  /**
   * STRUCTS
   */

  function configStorage() external view returns (address);

  function perpStorage() external view returns (address);

  function increasePosition(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _limitPriceE30
  ) external;

  function decreasePosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease,
    address _tpToken,
    uint256 _limitPriceE30
  ) external;

  function getNextFundingRate(
    uint256 _marketIndex,
    uint256 _price
  ) external view returns (int256 fundingRate, int256 fundingRateLong, int256 fundingRateShort);

  function getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice
  ) external pure returns (bool, uint256);

  function forceClosePosition(address _account, uint8 _subAccountId, uint256 _marketIndex, address _tpToken) external;
}
