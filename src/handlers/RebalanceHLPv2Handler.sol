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

/// @title RebalanceHLPv2Handler
/// @notice This contract act as an entry point for rebalancing HLP to GM(x) tokens
contract RebalanceHLPv2Handler is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error RebalanceHLPv2Handler_AddressIsZero();
  error RebalanceHLPv2Handler_NotWhiteListed();

  IRebalanceHLPv2Service public service;
  mapping(address => bool) public whitelistExecutors;

  event LogSetRebalanceHLPToGMXV2Service(address indexed _oldService, address indexed _newService);
  event LogSetWhitelistExecutor(address indexed _executor, bool _prevAllow, bool _isAllow);

  modifier onlyWhitelisted() {
    if (!whitelistExecutors[msg.sender]) revert RebalanceHLPv2Handler_NotWhiteListed();
    _;
  }

  function initialize(address _service) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    service = IRebalanceHLPv2Service(_service);
  }

  function executeDeposits(IRebalanceHLPv2Service.DepositParams[] calldata depositParams) external onlyWhitelisted {
    service.executeDeposits(depositParams);
  }

  function setWhitelistExecutor(address _executor, bool _isAllow) external onlyOwner {
    if (_executor == address(0)) {
      revert RebalanceHLPv2Handler_AddressIsZero();
    }
    emit LogSetWhitelistExecutor(_executor, whitelistExecutors[_executor], _isAllow);
    whitelistExecutors[_executor] = _isAllow;
  }

  function setRebalanceHLPToGMXV2Service(address _newService) external nonReentrant onlyOwner {
    if (_newService == address(0)) {
      revert RebalanceHLPv2Handler_AddressIsZero();
    }
    emit LogSetRebalanceHLPToGMXV2Service(address(service), _newService);
    service = IRebalanceHLPv2Service(_newService);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
