// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICrossMarginService {
  // ERRORs
  error ICrossMarginService_InvalidAddress();
  error ICrossMarginService_InsufficientBalance();
  error ICrossMarginService_WithdrawBalanceBelowIMR();

  /// @notice Set new ConfigStorage contract address.
  /// @dev This uses to retrive all config information on protocal.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external;

  /// @notice Set new CaultStorage contract address.
  /// @dev This uses to retrive all accounting information on protocal.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external;

  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to calculate new trader balance when they deposit token as collateral.
  /// @param _primaryAccount Trader's primary address from trader's wallet.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    address _primaryAccount,
    address _subAccount,
    address _token,
    uint256 _amount
  ) external;

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to calculate new trader balance when they withdrawing token as collateral.
  /// @param _primaryAccount Trader's primary address from trader's wallet.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  function withdrawCollateral(
    address _primaryAccount,
    address _subAccount,
    address _token,
    uint256 _amount
  ) external;
}
