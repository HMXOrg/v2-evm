// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IRebalanceHLPHandler } from "@hmx/handlers/interfaces/IRebalanceHLPHandler.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

/// @title RebalanceHLPHandler
/// @notice This contract handles liquidity orders for adding or removing liquidity from a pool
contract RebalanceHLPHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, IRebalanceHLPHandler {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint16 public constant BPS = 100_00;

  IRebalanceHLPService public service;
  IVaultStorage public vaultStorage;
  ICalculator public calculator;

  IERC20Upgradeable public sglp;

  uint16 public minExecutionFeeBPS;

  mapping(address => bool) public whitelistExecutors;

  event LogSetWhitelistExecutor(address indexed _account, bool _active);
  event LogSetMinExecutionFee(uint16 _oldFee, uint16 _newFee);
  event LogSetRebalanceHLPService(address indexed _oldService, address indexed _newService);

  modifier onlyWhitelisted() {
    // if not whitelist
    if (!whitelistExecutors[msg.sender]) {
      revert RebalanceHLPHandler_OnlyWhitelisted();
    }
    _;
  }

  function initialize(
    address _rebalanceHLPService,
    address _calculator,
    uint16 _minExecutionFeeBPS
  ) external initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    // gas opt
    IRebalanceHLPService _service = IRebalanceHLPService(_rebalanceHLPService);
    service = _service;
    vaultStorage = _service.vaultStorage();
    sglp = _service.sglp();
    calculator = ICalculator(_calculator);
    minExecutionFeeBPS = _minExecutionFeeBPS;
  }

  function setWhiteListExecutor(address _executor, bool _active) external onlyOwner {
    if (_executor == address(0)) {
      revert RebalanceHLPHandler_AddressIsZero();
    }
    whitelistExecutors[_executor] = _active;
    emit LogSetWhitelistExecutor(_executor, _active);
  }

  function setMinExecutionFeeBPS(uint16 _newExecutionFeeBPS) external onlyOwner {
    if (_newExecutionFeeBPS == 0) {
      revert RebalanceHLPHandler_AmountIsZero();
    }
    emit LogSetMinExecutionFee(minExecutionFeeBPS, _newExecutionFeeBPS);
    minExecutionFeeBPS = _newExecutionFeeBPS;
  }

  function setRebalanceHLPService(address _newService) external nonReentrant onlyOwner {
    if (_newService == address(0)) {
      revert RebalanceHLPHandler_AddressIsZero();
    }
    emit LogSetRebalanceHLPService(address(service), _newService);
    service = IRebalanceHLPService(_newService);
  }

  function executeLogicReinvestNonHLP(
    IRebalanceHLPService.ExecuteReinvestParams[] calldata _params
  ) external nonReentrant onlyWhitelisted returns (uint256 receivedGlp) {
    if (_params.length == 0) revert RebalanceHLPHandler_ParamsIsEmpty();
    _validateReinvestInput(_params);

    // Get current HLP value
    uint256 totalHlpValueBefore = calculator.getHLPValueE30(true);
    // Execute logic at Service
    receivedGlp = service.executReinvestNonHLP(_params);
    _validateHLPValue(totalHlpValueBefore);
  }

  function executeLogicWithdrawGLP(
    IRebalanceHLPService.ExecuteWithdrawParams[] calldata _params
  ) external nonReentrant onlyWhitelisted returns (IRebalanceHLPService.WithdrawGLPResult[] memory result) {
    if (_params.length == 0) revert RebalanceHLPHandler_ParamsIsEmpty();
    _validateWithdrawInput(_params);
    // Get current HLP value
    uint256 totalHlpValueBefore = calculator.getHLPValueE30(true);
    // Execute logic at Service
    result = service.executeWithdrawGLP(_params);

    _validateHLPValue(totalHlpValueBefore);
  }

  function _validateReinvestInput(IRebalanceHLPService.ExecuteReinvestParams[] calldata _params) internal {
    // SLOAD
    IVaultStorage _vaultStorage = vaultStorage;
    for (uint256 i = 0; i < _params.length; ) {
      if (_vaultStorage.totalAmount(_params[i].token) == 0) {
        revert RebalanceHLPHandler_InvalidTokenAddress();
      }
      if (_params[i].amount > _vaultStorage.totalAmount(_params[i].token)) {
        revert RebalanceHLPHandler_InvalidTokenAmount();
      }
      unchecked {
        ++i;
      }
    }
  }

  function _validateWithdrawInput(IRebalanceHLPService.ExecuteWithdrawParams[] calldata _params) internal {
    // SLOAD
    IVaultStorage _vaultStorage = vaultStorage;
    uint256 totalGlpAccum = 0;
    for (uint256 i = 0; i < _params.length; ) {
      if (_vaultStorage.totalAmount(_params[i].token) == 0) {
        revert RebalanceHLPHandler_InvalidTokenAddress();
      }
      totalGlpAccum += _params[i].glpAmount;
      unchecked {
        ++i;
      }
    }
    if (_vaultStorage.totalAmount(address(sglp)) < totalGlpAccum) {
      revert RebalanceHLPHandler_InvalidTokenAmount();
    }
  }

  function _validateHLPValue(uint256 _valueBefore) internal view {
    uint256 hlpValue = calculator.getHLPValueE30(true);
    if (_valueBefore < hlpValue) {
      uint256 diff = _valueBefore < hlpValue;
      if ((diff * (BPS ** 2)) >= (minExecutionFeeBPS * _valueBefore)) {
        revert RebalanceHLPHandler_HlpTvlDropExceedMin();
      }
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
