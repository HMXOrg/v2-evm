// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Owned } from "../base/Owned.sol";

// Interfaces
import { ICrossMarginHandler } from "./interfaces/ICrossMarginHandler.sol";
import { ICrossMarginService } from "../services/interfaces/ICrossMarginService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";

contract CrossMarginHandler is Owned, ReentrancyGuard, ICrossMarginHandler {
  // EVENTS
  event LogSetCrossMarginService(
    address indexed oldCrossMarginService,
    address newCrossMarginService
  );

  event LogSetConfigStorage(
    address indexed oldConfigStorage,
    address newConfigStorage
  );

  // STATES
  address public crossMarginService;
  address public configStorage;

  constructor(address _crossMarginService, address _configStorage) {
    // @todo sanyty check
    crossMarginService = _crossMarginService;
    configStorage = _configStorage;
  }

  /**
   * MODIFIER
   */

  // NOTE: Validate only accepted collateral token to be deposited
  modifier onlyAcceptedToken(address _token) {
    IConfigStorage(configStorage).validateAcceptedCollateral(_token);
    _;
  }

  /**
   * SETTER
   */

  /// @notice Set new CrossMarginService contract address.
  /// @param _crossMarginService New CrossMarginService contract address.
  function setCrossMarginService(
    address _crossMarginService
  ) external onlyOwner {
    // @todo - Sanity check
    if (_crossMarginService == address(0))
      revert ICrossMarginHandler_InvalidAddress();
    emit LogSetCrossMarginService(crossMarginService, _crossMarginService);
    crossMarginService = _crossMarginService;
  }

  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external onlyOwner {
    // @todo - Sanity check
    if (_configStorage == address(0))
      revert ICrossMarginHandler_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;
  }

  /**
   * CALCULATION
   */

  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to call deposit function on service and calculate new trader balance when they depositing token as collateral.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    address _account,
    uint256 _subAccountId,
    address _token,
    uint256 _amount
  ) external nonReentrant onlyAcceptedToken(_token) {
    // Get trader's sub-account address
    address _subAccount = _getSubAccount(_account, _subAccountId);

    // Call service to deposit collateral
    ICrossMarginService(crossMarginService).depositCollateral(
      _account,
      _subAccount,
      _token,
      _amount
    );
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to call withdraw function on service and calculate new trader balance when they withdrawing token as collateral.
  /// @param _account Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  function withdrawCollateral(
    address _account,
    uint256 _subAccountId,
    address _token,
    uint256 _amount
  ) external nonReentrant onlyAcceptedToken(_token) {
    // Get trader's sub-account address
    address _subAccount = _getSubAccount(_account, _subAccountId);

    // @todo set oracle price

    // Call service to withdraw collateral
    ICrossMarginService(crossMarginService).withdrawCollateral(
      _account,
      _subAccount,
      _token,
      _amount
    );
  }

  /// @notice Calculate subAccount address on trader.
  /// @dev This uses to create subAccount address combined between Primary account and SubAccount ID.
  /// @param _primary Trader's primary wallet account.
  /// @param _subAccountId Trader's sub account ID.
  /// @return _subAccount Trader's sub account address used for trading.
  function _getSubAccount(
    address _primary,
    uint256 _subAccountId
  ) internal pure returns (address _subAccount) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }
}
