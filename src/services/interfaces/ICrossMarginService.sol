// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICrossMarginService {
  /**
   * Errors
   */
  error ICrossMarginService_InvalidAddress();
  error ICrossMarginService_InvalidAmount();
  error ICrossMarginService_InvalidDepositBalance();
  error ICrossMarginService_InsufficientBalance();
  error ICrossMarginService_WithdrawBalanceBelowIMR();
  error ICrossMarginHandler_NoFundingFeeSurplus();
  error ICrossMarginHandler_FundingFeeSurplusCannotBeCovered();
  error ICrossMarginService_InvalidPath();
  error ICrossMarginService_Slippage();

  /**
   * States
   */
  function calculator() external returns (address);

  function configStorage() external returns (address _configStorage);

  function vaultStorage() external returns (address _vaultStorage);

  /**
   * Functions
   */
  function depositCollateral(address _primaryAccount, uint8 _subAccountId, address _token, uint256 _amount) external;

  function setCalculator(address _address) external;

  function withdrawCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    address _receiver
  ) external;

  function transferCollateralSubAccount(
    address _primaryAccount,
    uint8 _subAccountIdFrom,
    uint8 _subAccountIdTo,
    address _token,
    uint256 _amount
    ) external;

  function withdrawFundingFeeSurplus(address _stableToken) external;

  function setConfigStorage(address _configStorage) external;

  function setVaultStorage(address _vaultStorage) external;
}
