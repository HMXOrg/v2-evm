// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICrossMarginHandler {
  // ERRORs
  error ICrossMarginHandler_InvalidAddress();

  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to call deposit function on service and calculate new trader balance when they depositing token as collateral.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(address _account, uint256 _subAccountId, address _token, uint256 _amount) external;

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to call withdraw function on service and calculate new trader balance when they withdrawing token as collateral.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  /// @param _priceData Price update data
  function withdrawCollateral(
    address _account,
    uint256 _subAccountId,
    address _token,
    uint256 _amount,
    bytes[] memory _priceData
  ) external;
}
