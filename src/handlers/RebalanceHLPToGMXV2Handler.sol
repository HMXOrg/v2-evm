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
import { IRebalanceHLPToGMXV2Service } from "@hmx/services/interfaces/IRebalanceHLPToGMXV2Service.sol";
import { IRebalanceHLPToGMXV2Service } from "@hmx/services/interfaces/IRebalanceHLPToGMXV2Service.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IRebalanceHLPToGMXV2Service } from "@hmx/services/interfaces/IRebalanceHLPToGMXV2Service.sol";

/// @title RebalanceHLPToGMXV2Handler
/// @notice This contract handles liquidity orders for adding or removing liquidity from a pool
contract RebalanceHLPToGMXV2Handler is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error RebalanceHLPToGMXV2Handler_AddressIsZero();
  error RebalanceHLPToGMXV2Handler_NotWhiteListed();

  IRebalanceHLPToGMXV2Service public service;
  mapping(address => bool) public whitelistExecutors;

  event LogSetRebalanceHLPToGMXV2Service(address indexed _oldService, address indexed _newService);
  event LogSetWhitelistExecutor(address indexed _executor, bool _isAllow);

  modifier onlyWhitelisted() {
    if (!whitelistExecutors[msg.sender]) revert RebalanceHLPToGMXV2Handler_NotWhiteListed();
    _;
  }

  function initialize(address _service) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    service = IRebalanceHLPToGMXV2Service(_service);
  }

  function executeDeposits(
    IRebalanceHLPToGMXV2Service.DepositParams[] calldata depositParams
  ) external onlyWhitelisted {
    service.executeDeposits(depositParams);
  }

  function setWhitelistExecutor(address _executor, bool _isAllow) external onlyOwner {
    if (_executor == address(0)) {
      revert RebalanceHLPToGMXV2Handler_AddressIsZero();
    }
    whitelistExecutors[_executor] = _isAllow;
    emit LogSetWhitelistExecutor(_executor, _isAllow);
  }

  function setRebalanceHLPToGMXV2Service(address _newService) external nonReentrant onlyOwner {
    if (_newService == address(0)) {
      revert RebalanceHLPToGMXV2Handler_AddressIsZero();
    }
    emit LogSetRebalanceHLPToGMXV2Service(address(service), _newService);
    service = IRebalanceHLPToGMXV2Service(_newService);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
