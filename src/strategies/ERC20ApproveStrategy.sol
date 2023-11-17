// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IERC20ApproveStrategy } from "@hmx/strategies/interfaces/IERC20ApproveStrategy.sol";

contract ERC20ApproveStrategy is OwnableUpgradeable, IERC20ApproveStrategy {
  error ERC20ApproveStrategy_OnlyWhitelisted();

  IVaultStorage public vaultStorage;
  mapping(address => bool) public whitelistedExecutors;

  event LogSetWhitelistedExecutor(address indexed _account, bool _active);

  /**
   * Modifiers
   */
  modifier onlyWhitelist() {
    if (!whitelistedExecutors[msg.sender]) {
      revert ERC20ApproveStrategy_OnlyWhitelisted();
    }
    _;
  }

  function initialize(address _vaultStorage) external initializer {
    OwnableUpgradeable.__Ownable_init();
    vaultStorage = IVaultStorage(_vaultStorage);
  }

  function setWhitelistedExecutor(address _executor, bool _active) external onlyOwner {
    whitelistedExecutors[_executor] = _active;
    emit LogSetWhitelistedExecutor(_executor, _active);
  }

  function execute(address _token, address _spender, uint256 _amount) external onlyWhitelist {
    bytes memory _callData = abi.encodeWithSelector(IERC20Upgradeable.approve.selector, _spender, _amount);
    vaultStorage.cook(_token, _token, _callData);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
