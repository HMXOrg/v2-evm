// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { TraderLoyaltyCredit } from "@hmx/tokens/TraderLoyaltyCredit.sol";

import { EpochFeedableRewarder } from "./EpochFeedableRewarder.sol";

// import { IStaking } from "./interfaces/IStaking.sol";

contract TLCStaking is OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error PLPStaking_UnknownStakingToken();
  error PLPStaking_InsufficientTokenAmount();
  error PLPStaking_NotRewarder();
  error PLPStaking_NotCompounder();
  error PLPStaking_BadDecimals();
  error PLPStaking_DuplicateStakingToken();

  mapping(uint256 => mapping(address => uint256)) public userTokenAmount;
  mapping(address => bool) public isRewarder;
  address public stakingToken;
  address[] public rewarders;

  address public compounder;
  uint256 public epochLength;

  event LogDeposit(uint256 indexed epochTimestamp, address indexed caller, address indexed user, uint256 amount);
  event LogWithdraw(uint256 indexed epochTimestamp, address indexed caller, uint256 amount);
  event LogAddRewarder(address newRewarder);
  event LogSetCompounder(address oldCompounder, address newCompounder);

  function initialize() external initializer {
    OwnableUpgradeable.__Ownable_init();

    epochLength = 1 weeks;
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
    for (uint256 i = 0; i < length; ) {
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

  function deposit(address to, uint256 amount) external {
    uint256 length = rewarders.length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = rewarders[i];

      EpochFeedableRewarder(rewarder).onDeposit(getCurrentEpochTimestamp(), to, amount);

      unchecked {
        ++i;
      }
    }

    uint256 epochTimestamp = getCurrentEpochTimestamp();
    userTokenAmount[epochTimestamp][to] += amount;
    IERC20Upgradeable(stakingToken).safeTransferFrom(msg.sender, address(this), amount);

    emit LogDeposit(epochTimestamp, msg.sender, to, amount);
  }

  function getUserTokenAmount(uint256 epochTimestamp, address sender) external view returns (uint256) {
    return userTokenAmount[epochTimestamp][sender];
  }

  function withdraw(uint256 amount) external {
    _withdraw(amount);
    emit LogWithdraw(getCurrentEpochTimestamp(), msg.sender, amount);
  }

  function _withdraw(uint256 amount) internal {
    uint256 epochTimestamp = getCurrentEpochTimestamp();
    if (userTokenAmount[getCurrentEpochTimestamp()][msg.sender] < amount) revert PLPStaking_InsufficientTokenAmount();

    uint256 length = rewarders.length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = rewarders[i];

      EpochFeedableRewarder(rewarder).onWithdraw(
        EpochFeedableRewarder(rewarder).getCurrentEpochTimestamp(),
        msg.sender,
        amount
      );

      unchecked {
        ++i;
      }
    }
    userTokenAmount[epochTimestamp][msg.sender] -= amount;
    IERC20Upgradeable(stakingToken).safeTransfer(msg.sender, amount);
    emit LogWithdraw(epochTimestamp, msg.sender, amount);
  }

  function harvest(uint256 epochTimestamp, address[] memory _rewarders) external {
    _harvestFor(epochTimestamp, msg.sender, msg.sender, _rewarders);
  }

  function harvestToCompounder(
    address user,
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    address[] memory _rewarders
  ) external {
    if (compounder != msg.sender) revert PLPStaking_NotCompounder();
    uint256 epochTimestamp = startEpochTimestamp;
    for (uint256 i = 0; i < noOfEpochs; ) {
      _harvestFor(epochTimestamp, user, compounder, _rewarders);

      // Increment epoch timestamp

      epochTimestamp += epochLength;

      unchecked {
        ++i;
      }
    }
  }

  function _harvestFor(uint256 epochTimestamp, address user, address receiver, address[] memory _rewarders) internal {
    uint256 length = _rewarders.length;
    for (uint256 i = 0; i < length; ) {
      if (!isRewarder[_rewarders[i]]) {
        revert PLPStaking_NotRewarder();
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
    return TraderLoyaltyCredit(stakingToken).balanceOf(epochTimestamp, address(this));
  }

  function getCurrentEpochTimestamp() public view returns (uint256 epochTimestamp) {
    return (block.timestamp / epochLength) * epochLength;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
