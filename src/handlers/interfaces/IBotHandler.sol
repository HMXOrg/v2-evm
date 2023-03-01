// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IBotHandler {
  /**
   * Errors
   */
  error IBotHandler_UnauthorizedSender();

  /**
   * Functions
   */
  function forceTakeMaxProfit(address _account, uint256 _subAccountId, uint256 _marketIndex, address _tpToken) external;

  function setPositionManagers(address[] calldata _addresses, bool _isAllowed) external;
}
