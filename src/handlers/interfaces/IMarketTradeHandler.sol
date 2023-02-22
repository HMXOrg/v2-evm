// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IMarketTradeHandler {
  /**
   * ERRORs
   */
  error IMarketTradeHandler_InvalidAddress();
  error IMarketTradeHandler_PositionNotFullyClosed();
  error IMarketTradeHandler_ZeroSizeInput();
}
