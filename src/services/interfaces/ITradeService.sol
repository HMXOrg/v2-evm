// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

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
  error ITradeService_NotAllowDecrease();
  error ITradeService_BadNumberOfPosition();
  error ITradeService_BadExposure();
  error ITradeService_InvalidAveragePrice();
  error ITradeService_BadPositionSize();
  error ITradeService_InsufficientLiquidity();
  error ITradeService_InsufficientFreeCollateral();
  error ITradeService_ReservedValueStillEnough();
  error ITradeService_HlpHealthy();
  error ITradeService_MarketHealthy();
  error ITradeService_InvalidAddress();
  error ITradeService_PositionSizeExceed();

  /**
   * States
   */
  function calculator() external view returns (ICalculator);

  function configStorage() external view returns (address);

  function perpStorage() external view returns (address);

  function vaultStorage() external view returns (address);

  /**
   * Functions
   */
  function reloadConfig() external;

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

  function forceClosePosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken
  ) external returns (bool _isMaxProfit, bool _isProfit, uint256 _delta);

  function validateDeleverage() external view;

  function validateMarketDelisted(uint256 _marketIndex) external view;
}
