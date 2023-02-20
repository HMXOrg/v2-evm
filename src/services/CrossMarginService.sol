// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
  event LogSetConfigStorage(
    address indexed oldConfigStorage,
    address newConfigStorage
  );
  event LogSetVaultStorage(
    address indexed oldVaultStorage,
    address newVaultStorage
  );
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogIncreaseTokenLiquidity(
    address indexed trader,
    address token,
    uint256 amount
  );
  event LogDecreaseTokenLiquidity(
    address indexed trader,
    address token,
    uint256 amount
  );

  /**
   * States
   */
  address public configStorage;
  address public vaultStorage;
  address public calculator;

  constructor(
    address _configStorage,
    address _vaultStorage,
    address _calculator
  ) {
    // @todo - Sanity check
    if (
      _configStorage == address(0) ||
      _vaultStorage == address(0) ||
      _calculator == address(0)
    ) revert ICrossMarginService_InvalidAddress();

    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
    calculator = _calculator;
  }

  /**
   * Modifiers
   */
  // NOTE: Validate only whitelisted contract be able to call this function
  modifier onlyWhitelistedExecutor() {
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );
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
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    address _subAccount,
    address _token,
    uint256 _amount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) {
    // Get current collateral token balance of trader's account
    // and sum with new token depositing amount
    uint256 _oldBalance = IVaultStorage(vaultStorage).traderBalances(
      _subAccount,
      _token
    );

    uint256 _newBalance = _oldBalance + _amount;

    // Set new collateral token balance
    IVaultStorage(vaultStorage).setTraderBalance(
      _subAccount,
      _token,
      _newBalance
    );

    // If trader's account never contain this token before then register new token to the account
    if (_oldBalance == 0 && _newBalance != 0) {
      IVaultStorage(vaultStorage).addTraderToken(_subAccount, _token);
    }

    // Transfer depositing token from trader's wallet to VaultStorage
    IERC20(_token).transferFrom(msg.sender, vaultStorage, _amount);

    emit LogIncreaseTokenLiquidity(_subAccount, _token, _amount);
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to calculate new trader balance when they withdrawing token as collateral.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  function withdrawCollateral(
    address _subAccount,
    address _token,
    uint256 _amount
  ) external nonReentrant onlyWhitelistedExecutor onlyAcceptedToken(_token) {
    // Get current collateral token balance of trader's account
    // and deduct with new token withdrawing amount
    uint256 _oldBalance = IVaultStorage(vaultStorage).traderBalances(
      _subAccount,
      _token
    );
    if (_amount > _oldBalance) revert ICrossMarginService_InsufficientBalance();

    uint256 _newBalance = _oldBalance - _amount;

    // Set new collateral token balance
    IVaultStorage(vaultStorage).setTraderBalance(
      _subAccount,
      _token,
      _newBalance
    );

    // Calculate validation for if new Equity is below IMR or not
    if (
      ICalculator(calculator).getEquity(_subAccount) <
      ICalculator(calculator).getIMR(_subAccount)
    ) revert ICrossMarginService_WithdrawBalanceBelowIMR();

    // If trader withdraws all token out, then remove token on traderTokens list
    if (_oldBalance != 0 && _newBalance == 0) {
      IVaultStorage(vaultStorage).removeTraderToken(_subAccount, _token);
    }

    // Transfer withdrawing token from VaultStorage to trader's wallet
    IVaultStorage(vaultStorage).transferToken(_subAccount, _token, _amount);

    emit LogDecreaseTokenLiquidity(_subAccount, _token, _amount);
  }

  /**
   * Setter
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external onlyOwner {
    // @todo - Sanity check
    if (_configStorage == address(0))
      revert ICrossMarginService_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external onlyOwner {
    // @todo - Sanity check
    if (_vaultStorage == address(0))
      revert ICrossMarginService_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;
  }

  /// @notice Set new Calculator contract address.
  /// @param _calculator New Calculator contract address.
  function setCalculator(address _calculator) external onlyOwner {
    // @todo - Sanity check
    if (_calculator == address(0)) revert ICrossMarginService_InvalidAddress();

    emit LogSetCalculator(calculator, _calculator);
    calculator = _calculator;
  }
}
