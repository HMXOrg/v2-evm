// SPDX-License-Identifier: MIT
//   _   _ __  ____  __
//  | | | |  \/  \ \/ /
//  | |_| | |\/| |\  /
//  |  _  | |  | |/  \
//  |_| |_|_|  |_/_/\_\
//

pragma solidity 0.8.18;

interface ICrossMarginService {
  /**
   * Errors
   */
  error ICrossMarginService_InvalidDepositBalance();
  error ICrossMarginService_InvalidAddress();
  error ICrossMarginService_InsufficientBalance();
  error ICrossMarginService_WithdrawBalanceBelowIMR();
  error ICrossMarginHandler_NoFundingFeeSurplus();
  error ICrossMarginHandler_FundingFeeSurplusCannotBeCovered();

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

  function withdrawFundingFeeSurplus(address _stableToken) external;

  function setConfigStorage(address _configStorage) external;

  function setVaultStorage(address _vaultStorage) external;

  function convertSGlpCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minAmountOut
  ) external returns (uint256);
}
