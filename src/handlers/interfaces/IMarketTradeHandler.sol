// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IMarketTradeHandler {
  /**
   * Errors
   */
  error IMarketTradeHandler_InvalidAddress();
  error IMarketTradeHandler_PositionNotFullyClosed();
  error IMarketTradeHandler_ZeroSizeInput();
}
