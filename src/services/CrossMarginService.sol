// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { Owned } from "../base/Owned.sol";

// Interfaces
import { ICrossMarginService } from "./interfaces/ICrossMarginService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";

contract CrossMarginService is Owned, ReentrancyGuard, ICrossMarginService {
  // STATES
  address public configStorage;
  address public vaultStorage;

  // EVENTS
  event LogSetConfigStorage(
    address indexed oldConfigStorage,
    address newConfigStorage
  );

  event LogSetVaultStorage(
    address indexed oldVaultStorage,
    address newVaultStorage
  );

  event LogIncreaseTokenLiquidity(
    address indexed trader,
    address token,
    uint amount
  );

  event LogDecreaseTokenLiquidity(
    address indexed trader,
    address token,
    uint amount
  );

  constructor(address _configStorage, address _vaultStorage) {
    // Sanity check
    if (_configStorage == address(0) || _vaultStorage == address(0))
      revert ICrossMarginService_InvalidAddress();

    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER
  ////////////////////////////////////////////////////////////////////////////////////

  /// @notice Set new ConfigStorage contract address.
  /// @dev This uses to retrive all config information on protocal.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external onlyOwner {
    // Sanity check
    if (_configStorage == address(0))
      revert ICrossMarginService_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;
  }

  /// @notice Set new CaultStorage contract address.
  /// @dev This uses to retrive all accounting information on protocal.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external onlyOwner {
    // Sanity check
    if (_vaultStorage == address(0))
      revert ICrossMarginService_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  ////////////////////// CALCULATION
  ////////////////////////////////////////////////////////////////////////////////////

  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to calculate new trader balance when they deposit token as collateral.
  /// @param _subAccount Trader's address that combined between Primary account and Sub account.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    address _subAccount,
    address _token,
    uint256 _amount
  ) external nonReentrant {
    // Validate only whitelisted contract be able to call this function
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );
    // Validate only accepted collateral token to be deposited
    IConfigStorage(configStorage).validateAcceptedCollateral(_token);

    // Get current collateral token balance of trader's account
    // and sum with new token depositing amount
    uint oldBalance = IVaultStorage(vaultStorage).traderBalances(
      _subAccount,
      _token
    );
    uint newBalance = oldBalance + _amount;

    // Set new collateral token balance
    IVaultStorage(vaultStorage).setTraderBalance(
      _subAccount,
      _token,
      newBalance
    );

    // If trader's account never contain this token before then register new token to the account
    if (oldBalance == 0 && newBalance != 0) {
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
  ) external nonReentrant {
    // Validate only whitelisted contract be able to call this function
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );

    // Validate only accepted collateral token to be withdrawn
    IConfigStorage(configStorage).validateAcceptedCollateral(_token);

    // Get current collateral token balance of trader's account
    // and deduct with new token withdrawing amount
    uint oldBalance = IVaultStorage(vaultStorage).traderBalances(
      _subAccount,
      _token
    );
    if (_amount > oldBalance) revert ICrossMarginService_InsufficientBalance();

    // @todo - validate IMR in case withdraw
    uint newBalance = oldBalance - _amount;

    // Set new collateral token balance
    IVaultStorage(vaultStorage).setTraderBalance(
      _subAccount,
      _token,
      newBalance
    );

    // If trader withdraws all token out, then remove token on traderTokens list
    if (oldBalance != 0 && newBalance == 0) {
      IVaultStorage(vaultStorage).removeTraderToken(_subAccount, _token);
    }

    // Transfer withdrawing token from VaultStorage to trader's wallet
    IERC20(_token).transferFrom(vaultStorage, msg.sender, _amount);

    emit LogDecreaseTokenLiquidity(_subAccount, _token, _amount);
  }
}
