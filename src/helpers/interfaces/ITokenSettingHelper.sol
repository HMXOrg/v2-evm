// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITokenSettingHelper {
  /**
   * Errors
   */
  error ITokenSettingHelper_NotCollateralToken();

  /**
   * State
   */
  function getTokenSettingsBySubAccount(address subAccount) external view returns (address[] memory);

  /**
   * Functions
   */
  function setTokenSettings(uint8 _subAccountId, address[] memory _tokenSettings) external;
}
