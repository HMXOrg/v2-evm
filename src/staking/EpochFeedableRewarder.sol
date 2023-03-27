// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { TLCStaking } from "./TLCStaking.sol";
import { IRewarder } from "./interfaces/IRewarder.sol";
import { IEpochRewarder } from "./interfaces/IEpochRewarder.sol";

contract EpochFeedableRewarder is OwnableUpgradeable {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  string public name;
  address public rewardToken;
  address public staking;
  address public feeder;
  uint256 public epochLength;

  mapping(uint256 => uint256) public accRewardPerShareByEpochTimestamp;
  mapping(uint256 => uint256) rewardBalanceMapByEpochTimestamp;
  mapping(uint256 => mapping(address => bool)) isClaimed;
  uint256 private constant ACC_REWARD_PRECISION = 1e30;

  // Events
  event LogOnDeposit(address indexed user, uint256 shareAmount);
  event LogOnWithdraw(address indexed user, uint256 shareAmount);
  event LogHarvest(address indexed user, uint256 pendingRewardAmount);
  event LogUpdateRewardCalculationParams(uint64 lastRewardTime, uint256 accRewardPerShare);
  event LogFeed(uint256 feedAmount);
  event LogSetFeeder(address oldFeeder, address newFeeder);

  // Error
  error EpochFeedableRewarderError_FeedAmountDecayed();
  error EpochFeedableRewarderError_NotStakingContract();
  error EpochFeedableRewarderError_NotFeeder();
  error EpochFeedableRewarderError_BadDuration();
  error EpochFeedableRewarderError_WithdrawalNotAllowed();
  error EpochFeedableRewarderError_FutureEpoch();

  modifier onlyStakingContract() {
    if (msg.sender != staking) revert EpochFeedableRewarderError_NotStakingContract();
    _;
  }

  modifier onlyFeeder() {
    if (msg.sender != feeder) revert EpochFeedableRewarderError_NotFeeder();
    _;
  }

  function initialize(string memory name_, address rewardToken_, address staking_) external initializer {
    OwnableUpgradeable.__Ownable_init();

    name = name_;
    rewardToken = rewardToken_;
    staking = staking_;

    // At initialization, assume the feeder to be the contract owner
    feeder = owner();

    epochLength = 1 weeks;

    // Sanity check
    ERC20Upgradeable(rewardToken_).totalSupply();
    TLCStaking(staking_).isRewarder(address(this));
  }

  function onDeposit(uint256 epochTimestamp, address user, uint256 shareAmount) external onlyStakingContract {
    _updateRewardCalculationParams(epochTimestamp);

    emit LogOnDeposit(user, shareAmount);
  }

  function onWithdraw(uint256 epochTimestamp, address user, uint256 shareAmount) external onlyStakingContract {
    // Withdrawal will not be allowed is the epoch has ended.
    if (getCurrentEpochTimestamp() + epochLength > epochTimestamp)
      revert EpochFeedableRewarderError_WithdrawalNotAllowed();
    _updateRewardCalculationParams(epochTimestamp);

    emit LogOnWithdraw(user, shareAmount);
  }

  function onHarvest(uint256 epochTimestamp, address user, address receiver) external onlyStakingContract {
    if (!isClaimed[epochTimestamp][user]) {
      _updateRewardCalculationParams(epochTimestamp);

      uint256 accumulatedRewards = (_userShare(epochTimestamp, user) *
        accRewardPerShareByEpochTimestamp[epochTimestamp]) / ACC_REWARD_PRECISION;

      if (accumulatedRewards != 0) {
        isClaimed[epochTimestamp][user] = true;
        _harvestToken(receiver, accumulatedRewards);
      }

      emit LogHarvest(user, accumulatedRewards);
    }
  }

  function pendingReward(
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    address userAddress
  ) external view returns (uint256) {
    uint256 userShare;
    uint256 accumRewardPerShare;
    uint256 pendingRewardAmount;
    uint256 totalRewardAmount;
    uint256 epochTimestamp = (startEpochTimestamp / epochLength) * epochLength;
    for (uint256 i = 0; i < noOfEpochs; ) {
      // If the epoch is in the future, then break the loop
      if (epochTimestamp + epochLength > block.timestamp) break;

      // Get user balance of the epoch
      userShare = TLCStaking(staking).calculateShare(epochTimestamp, userAddress);
      // Get accum reward per share of the epoch
      accumRewardPerShare = accRewardPerShareByEpochTimestamp[epochTimestamp];

      // If userShare is zero, then the user will not be eligible for reward in that epoch.
      // If accumRewardPerShare is zero, then the reward might not be distributed for that epoch yet. We will skip without burning user share.
      if (userShare > 0 && accumRewardPerShare > 0) {
        // Calculate pending reward
        pendingRewardAmount = (userShare * accumRewardPerShare) / ACC_REWARD_PRECISION;
        totalRewardAmount += pendingRewardAmount;
      }

      // Increment epoch timestamp
      epochTimestamp += epochLength;

      unchecked {
        ++i;
      }
    }
    return totalRewardAmount;
  }

  function feed(uint256 epochTimestamp, uint256 feedAmount) external onlyFeeder {
    _feed(epochTimestamp, feedAmount);
  }

  function setFeeder(address feeder_) external onlyOwner {
    emit LogSetFeeder(feeder, feeder_);
    feeder = feeder_;
  }

  function _feed(uint256 epochTimestamp, uint256 feedAmount) internal {
    // Floor down the timestamp, in case it is incorrectly formatted
    epochTimestamp = (epochTimestamp / epochLength) * epochLength;

    if (epochTimestamp > block.timestamp) revert EpochFeedableRewarderError_FutureEpoch();

    {
      // Transfer token, with decay check
      uint256 balanceBefore = ERC20Upgradeable(rewardToken).balanceOf(address(this));
      ERC20Upgradeable(rewardToken).safeTransferFrom(msg.sender, address(this), feedAmount);

      if (ERC20Upgradeable(rewardToken).balanceOf(address(this)) - balanceBefore != feedAmount)
        revert EpochFeedableRewarderError_FeedAmountDecayed();
    }

    rewardBalanceMapByEpochTimestamp[epochTimestamp] += feedAmount;

    _updateRewardCalculationParams(epochTimestamp);

    emit LogFeed(feedAmount);
  }

  function _updateRewardCalculationParams(uint256 epochTimestamp) internal {
    uint256 totalShare = _totalShare(epochTimestamp);
    if (totalShare > 0) {
      accRewardPerShareByEpochTimestamp[epochTimestamp] =
        (rewardBalanceMapByEpochTimestamp[epochTimestamp] * ACC_REWARD_PRECISION) /
        totalShare;
    }
  }

  function _totalShare(uint256 epochTimestamp) private view returns (uint256) {
    return TLCStaking(staking).calculateTotalShare(epochTimestamp);
  }

  function _userShare(uint256 epochTimestamp, address user) private view returns (uint256) {
    return TLCStaking(staking).calculateShare(epochTimestamp, user);
  }

  function _harvestToken(address receiver, uint256 pendingRewardAmount) internal virtual {
    ERC20Upgradeable(rewardToken).safeTransfer(receiver, pendingRewardAmount);
  }

  function getCurrentEpochTimestamp() public view returns (uint256 epochTimestamp) {
    return (block.timestamp / epochLength) * epochLength;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
