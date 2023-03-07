// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IMarketTradeHandler {
  /**
   * Errors
   */
  error IMarketTradeHandler_InvalidAddress();
  error IMarketTradeHandler_PositionNotFullyClosed();
  error IMarketTradeHandler_ZeroSizeInput();

  function setTradeService(address _newTradeService) external;

  function setPyth(address _newPyth) external;

  function buy(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _buySizeE30,
    address _tpToken,
    bytes[] memory _priceData
  ) external;

  function sell(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _sellSizeE30,
    address _tpToken,
    bytes[] memory _priceData
  ) external;
}
