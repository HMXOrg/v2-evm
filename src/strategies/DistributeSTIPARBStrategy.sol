// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { IDistributeSTIPARBStrategy } from "@hmx/strategies/interfaces/IDistributeSTIPARBStrategy.sol";
import { IERC20ApproveStrategy } from "@hmx/strategies/interfaces/IERC20ApproveStrategy.sol";

contract DistributeSTIPARBStrategy is OwnableUpgradeable, IDistributeSTIPARBStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  error DistributeSTIPARBStrategy_OnlyWhitelisted();

  IVaultStorage public vaultStorage;
  IRewarder public rewarder;
  IERC20Upgradeable public arb;
  IERC20ApproveStrategy public approveStrat;
  uint256 public devFeeBps;
  address public treasury;
  mapping(address => bool) public whitelistedExecutors;

  event LogSetWhitelistedExecutor(address indexed _account, bool _active);
  event LogDistributeARBRewardsFromSTIP(uint256 distributedAmount, uint256 devFeeAmount, uint256 expiredAt);

  /**
   * Modifiers
   */
  modifier onlyWhitelist() {
    if (!whitelistedExecutors[msg.sender]) {
      revert DistributeSTIPARBStrategy_OnlyWhitelisted();
    }
    _;
  }

  function initialize(
    address _vaultStorage,
    address _rewarder,
    address _arb,
    uint256 _devFeeBps,
    address _treasury,
    address _approveStrat
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    vaultStorage = IVaultStorage(_vaultStorage);
    rewarder = IRewarder(_rewarder);
    arb = IERC20Upgradeable(_arb);
    devFeeBps = _devFeeBps;
    treasury = _treasury;
    approveStrat = IERC20ApproveStrategy(_approveStrat);
  }

  function setWhitelistedExecutor(address _executor, bool _active) external onlyOwner {
    whitelistedExecutors[_executor] = _active;
    emit LogSetWhitelistedExecutor(_executor, _active);
  }

  function execute(uint256 _amount, uint256 _expiredAt) external onlyWhitelist {
    // 1. Collect dev fee
    uint256 _distributedAmount = _amount;
    uint256 _devFeeAmount;
    if (devFeeBps > 0) {
      _devFeeAmount = (_amount * devFeeBps) / 10000;
      _distributedAmount -= _devFeeAmount;
      vaultStorage.pushToken(address(arb), treasury, _devFeeAmount);
    }

    // 2. Approve ARB to rewarder
    approveStrat.execute(address(arb), address(rewarder), _distributedAmount);

    // 3. Feed ARB to rewarder
    bytes memory _callData = abi.encodeWithSelector(
      IRewarder.feedWithExpiredAt.selector,
      _distributedAmount,
      _expiredAt
    );
    vaultStorage.cook(address(arb), address(rewarder), _callData);

    // 4. Update accounting at VaultStorage
    vaultStorage.pushToken(address(arb), address(this), 0);

    emit LogDistributeARBRewardsFromSTIP(_distributedAmount, _devFeeAmount, _expiredAt);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
