// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// lib
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";

/// @title RebalanceHLPv2Handler
/// @notice This contract act as an entry point for rebalancing HLP to GM(x) tokens
contract RebalanceHLPv2Handler is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error RebalanceHLPv2Handler_AddressIsZero();
  error RebalanceHLPv2Handler_ExecutionFeeBelowMin();
  error RebalanceHLPv2Handler_ExecutionFeeTooLow();
  error RebalanceHLPv2Handler_NotWhiteListed();

  // Configurable states
  IRebalanceHLPv2Service public service;
  IWNative public weth;
  uint256 public minExecutionFee;
  mapping(address => bool) public whitelistExecutors;

  event LogSetMinExecutionFee(uint256 _oldValue, uint256 _newValue);
  event LogSetRebalanceHLPToGMXV2Service(address indexed _oldService, address indexed _newService);
  event LogSetWhitelistExecutor(address indexed _executor, bool _prevAllow, bool _isAllow);

  modifier onlyWhitelisted() {
    if (!whitelistExecutors[msg.sender]) revert RebalanceHLPv2Handler_NotWhiteListed();
    _;
  }

  function initialize(address _service, IWNative _weth, uint256 _minExecutionFee) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    service = IRebalanceHLPv2Service(_service);
    weth = _weth;
    minExecutionFee = _minExecutionFee;

    IERC20Upgradeable(address(_weth)).safeApprove(_service, type(uint256).max);
  }

  function createDepositOrders(
    IRebalanceHLPv2Service.DepositParams[] calldata _depositParams,
    uint256 _executionFee
  ) external payable nonReentrant onlyWhitelisted returns (bytes32[] memory) {
    // Check
    if (_executionFee < minExecutionFee) revert RebalanceHLPv2Handler_ExecutionFeeBelowMin();
    if (msg.value != _depositParams.length * _executionFee) revert RebalanceHLPv2Handler_ExecutionFeeTooLow();

    // Interact
    // Wrap ETH to WETH
    weth.deposit{ value: msg.value }();

    return service.createDepositOrders(_depositParams, _executionFee);
  }

  function createWithdrawalOrders(
    IRebalanceHLPv2Service.WithdrawalParams[] calldata _withdrawalParams,
    uint256 _executionFee
  ) external payable nonReentrant onlyWhitelisted returns (bytes32[] memory) {
    // Check
    if (_executionFee < minExecutionFee) revert RebalanceHLPv2Handler_ExecutionFeeBelowMin();
    if (msg.value != _withdrawalParams.length * _executionFee) revert RebalanceHLPv2Handler_ExecutionFeeTooLow();

    // Interact
    // Wrap ETH to WETH
    weth.deposit{ value: msg.value }();

    return service.createWithdrawalOrders(_withdrawalParams, _executionFee);
  }

  function setMinExecutionFee(uint256 _newMinExecutionFee) external onlyOwner {
    emit LogSetMinExecutionFee(minExecutionFee, _newMinExecutionFee);
    minExecutionFee = _newMinExecutionFee;
  }

  function setRebalanceHLPv2Service(address _newService) external onlyOwner {
    // Check
    if (_newService == address(0)) {
      revert RebalanceHLPv2Handler_AddressIsZero();
    }

    // Effect
    emit LogSetRebalanceHLPToGMXV2Service(address(service), _newService);
    service = IRebalanceHLPv2Service(_newService);

    // Interaction
    // Approve new service to spend WETH
    IERC20Upgradeable(address(weth)).safeApprove(_newService, type(uint256).max);
  }

  function setWhitelistExecutor(address _executor, bool _isAllow) external onlyOwner {
    if (_executor == address(0)) {
      revert RebalanceHLPv2Handler_AddressIsZero();
    }
    emit LogSetWhitelistExecutor(_executor, whitelistExecutors[_executor], _isAllow);
    whitelistExecutors[_executor] = _isAllow;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
