// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { Owned } from "../base/Owned.sol";

// Interfaces
import { ICrossMarginService } from "./interfaces/ICrossMarginService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";

contract CrossMarginService is Owned, ReentrancyGuard, ICrossMarginService {
  /**
   * Events
   */
  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogDepositCollateral(address indexed primaryAccount, address indexed subAccount, address token, uint256 amount);
  event LogWithdrawCollateral(
    address indexed primaryAccount,
    address indexed subAccount,
    address token,
    uint256 amount
  );

  /**
   * States
   */
  address public configStorage;
  address public vaultStorage;
  address public calculator;

  constructor(address _configStorage, address _vaultStorage, address _calculator) {
    if (_configStorage == address(0) || _vaultStorage == address(0) || _calculator == address(0))
      revert ICrossMarginService_InvalidAddress();

    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
    calculator = _calculator;

    // Sanity check
    IConfigStorage(_configStorage).calculator();
    IVaultStorage(_vaultStorage).devFees(address(0));
    ICalculator(_calculator).oracle();
  }

  /**
   * Modifiers
   */
  // NOTE: Validate only whitelisted contract be able to call this function
  modifier onlyWhitelistedExecutor() {
    IConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  // NOTE: Validate only accepted collateral token to be deposited
  modifier onlyAcceptedToken(address _token) {
    IConfigStorage(configStorage).validateAcceptedCollateral(_token);
    _;
  }

  /**
   * Core functions
   */
  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to calculate new trader balance when they deposit token as collateral.
  /// @param _primaryAccount Trader's primary address from trader's wallet.
  /// @param _subAccountId Trader's Sub-Account Id.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    address _token,
    uint256 _amount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) {
    address _vaultStorage = vaultStorage;

    // Get trader's sub-account address
    address _subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // Get current collateral token balance of trader's account
    // and sum with new token depositing amount
    uint256 _oldBalance = IVaultStorage(_vaultStorage).traderBalances(_subAccount, _token);

    uint256 _newBalance = _oldBalance + _amount;

    // Set new collateral token balance
    IVaultStorage(_vaultStorage).setTraderBalance(_subAccount, _token, _newBalance);

    // Update token balance
    uint256 deltaBalance = IVaultStorage(_vaultStorage).pullToken(_token);
    if (deltaBalance < _amount) revert ICrossMarginService_InvalidDepositBalance();

    // If trader's account never contain this token before then register new token to the account
    if (_oldBalance == 0 && _newBalance != 0) {
      IVaultStorage(_vaultStorage).addTraderToken(_subAccount, _token);
    }

    emit LogDepositCollateral(_primaryAccount, _subAccount, _token, _amount);
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to calculate new trader balance when they withdrawing token as collateral.
  /// @param _primaryAccount Trader's primary address from trader's wallet.
  /// @param _subAccountId Trader's Sub-Account Id.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  function withdrawCollateral(
    address _primaryAccount,
    uint8 _subAccountId,
    address _token,
    uint256 _amount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) {
    address _vaultStorage = vaultStorage;

    // Get trader's sub-account address
    address _subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // Get current collateral token balance of trader's account
    // and deduct with new token withdrawing amount
    uint256 _oldBalance = IVaultStorage(_vaultStorage).traderBalances(_subAccount, _token);
    if (_amount > _oldBalance) revert ICrossMarginService_InsufficientBalance();

    uint256 _newBalance = _oldBalance - _amount;

    // Set new collateral token balance
    IVaultStorage(_vaultStorage).setTraderBalance(_subAccount, _token, _newBalance);

    // Calculate validation for if new Equity is below IMR or not
    int256 equity = ICalculator(calculator).getEquity(_subAccount, 0, 0);
    if (equity < 0 || uint256(equity) < ICalculator(calculator).getIMR(_subAccount))
      revert ICrossMarginService_WithdrawBalanceBelowIMR();

    // If trader withdraws all token out, then remove token on traderTokens list
    if (_oldBalance != 0 && _newBalance == 0) {
      IVaultStorage(_vaultStorage).removeTraderToken(_subAccount, _token);
    }

    // Transfer withdrawing token from VaultStorage to trader's wallet
    IVaultStorage(_vaultStorage).pushToken(_token, _primaryAccount, _amount);

    emit LogWithdrawCollateral(_primaryAccount, _subAccount, _token, _amount);
  }

  /**
   * Setter
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external nonReentrant onlyOwner {
    if (_configStorage == address(0)) revert ICrossMarginService_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;

    // Sanity check
    IConfigStorage(_configStorage).calculator();
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external nonReentrant onlyOwner {
    if (_vaultStorage == address(0)) revert ICrossMarginService_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;

    // Sanity check
    IVaultStorage(_vaultStorage).devFees(address(0));
  }

  /// @notice Set new Calculator contract address.
  /// @param _calculator New Calculator contract address.
  function setCalculator(address _calculator) external nonReentrant onlyOwner {
    if (_calculator == address(0)) revert ICrossMarginService_InvalidAddress();

    emit LogSetCalculator(calculator, _calculator);
    calculator = _calculator;

    // Sanity check
    ICalculator(_calculator).oracle();
  }

  /// @notice Calculate subAccount address on trader.
  /// @dev This uses to create subAccount address combined between Primary account and SubAccount ID.
  /// @param _primary Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @return _subAccount Trader's sub account address used for trading.
  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address _subAccount) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }
}
