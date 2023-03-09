// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IBotHandler {
  /**
   * Errors
   */
  error IBotHandler_UnauthorizedSender();

  /**
   * States
   */
  function tradeService() external returns (address);

  function positionManagers(address _account) external returns (bool);

  /**
   * Functions
   */
  function forceTakeMaxProfit(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes[] memory _priceData
  ) external;

  function deleverage(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes[] memory _priceData
  ) external;

  function closeDelistedMarketPosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes[] memory _priceData
  ) external;

  function liquidate(address _subAccount, bytes[] memory _priceData) external;

  function setPositionManagers(address[] calldata _addresses, bool _isAllowed) external;

  function setTradeService(address _newAddress) external;
}
