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

  struct SwitchCollateralParams {
    address primaryAccount;
    uint8 subAccountId;
    uint248 amount;
    address[] path;
    uint256 minToAmount;
  }


  struct TransferCollateralParams {
    address fromPrimaryAccount;
    uint8 fromSubAccountId;
    address toPrimaryAccount;
    uint8 toSubAccountId;
    address token;
    uint256 amount;
  }

  /**
   * States
   */
  function calculator() external view returns (address);

  function configStorage() external view returns (address _configStorage);

  function vaultStorage() external view returns (address _vaultStorage);

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

  function transferCollateral(TransferCollateralParams calldata _params) external;

  function withdrawFundingFeeSurplus(address _stableToken) external;

  function switchCollateral(SwitchCollateralParams calldata _params) external returns (uint256 _toAmount);

  function setConfigStorage(address _configStorage) external;

  function setVaultStorage(address _vaultStorage) external;
}
