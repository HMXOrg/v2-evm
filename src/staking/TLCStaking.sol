// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { EpochFeedableRewarder } from "./EpochFeedableRewarder.sol";

import { ITLCStaking } from "./interfaces/ITLCStaking.sol";

contract TLCStaking is OwnableUpgradeable, ITLCStaking {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error TLCStaking_InsufficientTokenAmount();
  error TLCStaking_NotRewarder();
  error TLCStaking_NotCompounder();
  error TLCStaking_Forbidden();

  mapping(uint256 epochTimestamp => mapping(address user => uint256 amount)) public userTokenAmount;
  mapping(uint256 epochTimestamp => uint256 amount) public totalTokenAmount;
  mapping(address rewarder => bool isRewarder) public isRewarder;
  address public stakingToken;
  address[] public rewarders;
  address public compounder;
  uint256 public epochLength;
  address public whitelistedCaller;

  event LogDeposit(uint256 indexed epochTimestamp, address indexed caller, address indexed user, uint256 amount);
  event LogWithdraw(uint256 indexed epochTimestamp, address indexed caller, uint256 amount);
  event LogAddRewarder(address newRewarder);
  event LogSetCompounder(address oldCompounder, address newCompounder);
  event LogSetWhitelistedCaller(address oldAddress, address newAddress);

  function initialize(address _stakingToken) external initializer {
    OwnableUpgradeable.__Ownable_init();

    stakingToken = _stakingToken;
    epochLength = 1 weeks;

    // Sanity Checks
    IERC20Upgradeable(stakingToken).totalSupply();
  }

  /**
   * Modifiers
   */
  modifier onlyWhitelistedCaller() {
    if (msg.sender != whitelistedCaller) revert TLCStaking_Forbidden();
    _;
  }

  function addRewarder(address newRewarder) external onlyOwner {
    _updatePool(newRewarder);

    emit LogAddRewarder(newRewarder);
  }

  function removeRewarder(uint256 removeRewarderIndex) external onlyOwner {
    address removedRewarder = rewarders[removeRewarderIndex];
    rewarders[removeRewarderIndex] = rewarders[rewarders.length - 1];
    rewarders[rewarders.length - 1] = removedRewarder;
    rewarders.pop();
    isRewarder[removedRewarder] = false;
  }

  function _updatePool(address newRewarder) internal {
    if (!isDuplicatedRewarder(newRewarder)) rewarders.push(newRewarder);

    if (!isRewarder[newRewarder]) {
      isRewarder[newRewarder] = true;
    }
  }

  function isDuplicatedRewarder(address rewarder) internal view returns (bool) {
    uint256 length = rewarders.length;
    for (uint256 i; i < length; ) {
      if (rewarders[i] == rewarder) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }

  function setCompounder(address compounder_) external onlyOwner {
    emit LogSetCompounder(compounder, compounder_);
    compounder = compounder_;
  }

  function deposit(address to, uint256 amount) external onlyWhitelistedCaller {
    uint256 epochTimestamp = getCurrentEpochTimestamp();
    userTokenAmount[epochTimestamp][to] += amount;
    totalTokenAmount[epochTimestamp] += amount;

    uint256 length = rewarders.length;
    for (uint256 i; i < length; ) {
      address rewarder = rewarders[i];

      EpochFeedableRewarder(rewarder).onDeposit(epochTimestamp, to, amount);

      unchecked {
        ++i;
      }
    }

    IERC20Upgradeable(stakingToken).safeTransferFrom(msg.sender, address(this), amount);

    emit LogDeposit(epochTimestamp, msg.sender, to, amount);
  }

  function getUserTokenAmount(uint256 epochTimestamp, address sender) external view returns (uint256) {
    // Floor down the timestamp, in case it is incorrectly formatted
    epochTimestamp = (epochTimestamp / epochLength) * epochLength;

    return userTokenAmount[epochTimestamp][sender];
  }

  function withdraw(address to, uint256 amount) external onlyWhitelistedCaller {
    _withdraw(to, amount);
    emit LogWithdraw(getCurrentEpochTimestamp(), msg.sender, amount);
  }

  function _withdraw(address to, uint256 amount) internal {
    uint256 epochTimestamp = getCurrentEpochTimestamp();
    if (userTokenAmount[epochTimestamp][to] < amount) revert TLCStaking_InsufficientTokenAmount();

    userTokenAmount[epochTimestamp][to] -= amount;
    totalTokenAmount[epochTimestamp] -= amount;

    uint256 length = rewarders.length;
    for (uint256 i; i < length; ) {
      address rewarder = rewarders[i];

      EpochFeedableRewarder(rewarder).onWithdraw(epochTimestamp, to, amount);

      unchecked {
        ++i;
      }
    }

    IERC20Upgradeable(stakingToken).safeTransfer(to, amount);

    emit LogWithdraw(epochTimestamp, to, amount);
  }

  function harvest(uint256 startEpochTimestamp, uint256 noOfEpochs, address[] memory _rewarders) external {
    uint256 epochTimestamp = (startEpochTimestamp / epochLength) * epochLength;
    for (uint256 i; i < noOfEpochs; ) {
      // If the epoch is in the future, then break the loop
      if (epochTimestamp + epochLength > block.timestamp) break;

      _harvestFor(epochTimestamp, msg.sender, msg.sender, _rewarders);

      // Increment epoch timestamp
      epochTimestamp += epochLength;

      unchecked {
        ++i;
      }
    }
  }

  function harvestToCompounder(
    address user,
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    address[] memory _rewarders
  ) external {
    if (compounder != msg.sender) revert TLCStaking_NotCompounder();
    uint256 epochTimestamp = (startEpochTimestamp / epochLength) * epochLength;
    for (uint256 i; i < noOfEpochs; ) {
      // If the epoch is in the future, then break the loop
      if (epochTimestamp + epochLength > block.timestamp) break;

      _harvestFor(epochTimestamp, user, compounder, _rewarders);

      // Increment epoch timestamp
      epochTimestamp += epochLength;

      unchecked {
        ++i;
      }
    }
  }

  function _harvestFor(uint256 epochTimestamp, address user, address receiver, address[] memory _rewarders) internal {
    // Floor down the timestamp, in case it is incorrectly formatted
    epochTimestamp = (epochTimestamp / epochLength) * epochLength;

    uint256 length = _rewarders.length;
    for (uint256 i; i < length; ) {
      if (!isRewarder[_rewarders[i]]) {
        revert TLCStaking_NotRewarder();
      }

      EpochFeedableRewarder(_rewarders[i]).onHarvest(epochTimestamp, user, receiver);

      unchecked {
        ++i;
      }
    }
  }

  function calculateShare(uint256 epochTimestamp, address user) external view returns (uint256) {
    return userTokenAmount[epochTimestamp][user];
  }

  function calculateTotalShare(uint256 epochTimestamp) external view returns (uint256) {
    return totalTokenAmount[epochTimestamp];
  }

  function getCurrentEpochTimestamp() public view returns (uint256 epochTimestamp) {
    unchecked {
      epochTimestamp = (block.timestamp / epochLength) * epochLength;
    }
  }

  function getRewarders() external view returns (address[] memory) {
    return rewarders;
  }

  /// @dev Set the address of an account authorized to modify balances in CrossMarginTrading.sol contract
  /// Emits a LogSetWhitelistedCaller event.
  /// @param _whitelistedCaller The new address allowed to perform whitelisted calls.
  function setWhitelistedCaller(address _whitelistedCaller) external onlyOwner {
    emit LogSetWhitelistedCaller(whitelistedCaller, _whitelistedCaller);
    whitelistedCaller = _whitelistedCaller;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
