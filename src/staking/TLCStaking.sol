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

  mapping(address => mapping(address => uint256)) public userTokenAmount;
  mapping(address => bool) public isRewarder;
  mapping(address => bool) public isStakingToken;
  mapping(address => address[]) public stakingTokenRewarders;
  mapping(address => address[]) public rewarderStakingTokens;

  address public compounder;
  uint256 public epochLength;

  event LogDeposit(address indexed caller, address indexed user, address token, uint256 amount);
  event LogWithdraw(address indexed caller, address token, uint256 amount);
  event LogAddStakingToken(address newToken, address[] newRewarders);
  event LogAddRewarder(address newRewarder, address[] newTokens);
  event LogSetCompounder(address oldCompounder, address newCompounder);

  function initialize() external initializer {
    OwnableUpgradeable.__Ownable_init();

    epochLength = 1 weeks;
  }

  function addStakingToken(address newToken, address[] memory newRewarders) external onlyOwner {
    if (ERC20Upgradeable(newToken).decimals() != 18) revert PLPStaking_BadDecimals();

    uint256 length = newRewarders.length;
    for (uint256 i = 0; i < length; ) {
      _updatePool(newToken, newRewarders[i]);

      emit LogAddStakingToken(newToken, newRewarders);
      unchecked {
        ++i;
      }
    }
  }

  function addRewarder(address newRewarder, address[] memory newTokens) external onlyOwner {
    uint256 length = newTokens.length;
    for (uint256 i = 0; i < length; ) {
      if (ERC20Upgradeable(newTokens[i]).decimals() != 18) revert PLPStaking_BadDecimals();

      _updatePool(newTokens[i], newRewarder);

      emit LogAddRewarder(newRewarder, newTokens);
      unchecked {
        ++i;
      }
    }
  }

  function removeRewarderForTokenByIndex(uint256 removeRewarderIndex, address token) external onlyOwner {
    uint256 tokenLength = stakingTokenRewarders[token].length;
    address removedRewarder = stakingTokenRewarders[token][removeRewarderIndex];
    stakingTokenRewarders[token][removeRewarderIndex] = stakingTokenRewarders[token][tokenLength - 1];
    stakingTokenRewarders[token].pop();

    uint256 rewarderLength = rewarderStakingTokens[removedRewarder].length;
    for (uint256 i = 0; i < rewarderLength; ) {
      if (rewarderStakingTokens[removedRewarder][i] == token) {
        rewarderStakingTokens[removedRewarder][i] = rewarderStakingTokens[removedRewarder][rewarderLength - 1];
        rewarderStakingTokens[removedRewarder].pop();
        if (rewarderLength == 1) isRewarder[removedRewarder] = false;

        break;
      }
      unchecked {
        ++i;
      }
    }
  }

  function _updatePool(address newToken, address newRewarder) internal {
    if (!isDuplicatedRewarder(newToken, newRewarder)) stakingTokenRewarders[newToken].push(newRewarder);
    if (!isDuplicatedStakingToken(newToken, newRewarder)) rewarderStakingTokens[newRewarder].push(newToken);

    isStakingToken[newToken] = true;
    if (!isRewarder[newRewarder]) {
      isRewarder[newRewarder] = true;
    }
  }

  function isDuplicatedRewarder(address stakingToken, address rewarder) internal view returns (bool) {
    uint256 length = stakingTokenRewarders[stakingToken].length;
    for (uint256 i = 0; i < length; ) {
      if (stakingTokenRewarders[stakingToken][i] == rewarder) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }

  function isDuplicatedStakingToken(address stakingToken, address rewarder) internal view returns (bool) {
    uint256 length = rewarderStakingTokens[rewarder].length;
    for (uint256 i = 0; i < length; ) {
      if (rewarderStakingTokens[rewarder][i] == stakingToken) {
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

  function deposit(address to, address token, uint256 amount) external {
    if (!isStakingToken[token]) revert PLPStaking_UnknownStakingToken();

    uint256 length = stakingTokenRewarders[token].length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = stakingTokenRewarders[token][i];

      EpochFeedableRewarder(rewarder).onDeposit(getCurrentEpochTimestamp(), to, amount);

      unchecked {
        ++i;
      }
    }

    userTokenAmount[token][to] += amount;
    IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);

    emit LogDeposit(msg.sender, to, token, amount);
  }

  function getUserTokenAmount(address token, address sender) external view returns (uint256) {
    return userTokenAmount[token][sender];
  }

  function getStakingTokenRewarders(address token) external view returns (address[] memory) {
    return stakingTokenRewarders[token];
  }

  function withdraw(address token, uint256 amount) external {
    _withdraw(token, amount);
    emit LogWithdraw(msg.sender, token, amount);
  }

  function _withdraw(address token, uint256 amount) internal {
    if (!isStakingToken[token]) revert PLPStaking_UnknownStakingToken();
    if (userTokenAmount[token][msg.sender] < amount) revert PLPStaking_InsufficientTokenAmount();

    uint256 length = stakingTokenRewarders[token].length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = stakingTokenRewarders[token][i];

      EpochFeedableRewarder(rewarder).onWithdraw(
        EpochFeedableRewarder(rewarder).getCurrentEpochTimestamp(),
        msg.sender,
        amount
      );

      unchecked {
        ++i;
      }
    }
    userTokenAmount[token][msg.sender] -= amount;
    IERC20Upgradeable(token).safeTransfer(msg.sender, amount);
    emit LogWithdraw(msg.sender, token, amount);
  }

  function harvest(uint256 epochTimestamp, address[] memory rewarders) external {
    _harvestFor(epochTimestamp, msg.sender, msg.sender, rewarders);
  }

  function harvestToCompounder(
    address user,
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    address[] memory rewarders
  ) external {
    if (compounder != msg.sender) revert PLPStaking_NotCompounder();
    uint256 epochTimestamp = startEpochTimestamp;
    for (uint256 i = 0; i < noOfEpochs; ) {
      _harvestFor(epochTimestamp, user, compounder, rewarders);

      // Increment epoch timestamp

      epochTimestamp += epochLength;

      unchecked {
        ++i;
      }
    }
  }

  function _harvestFor(uint256 epochTimestamp, address user, address receiver, address[] memory rewarders) internal {
    uint256 length = rewarders.length;
    for (uint256 i = 0; i < length; ) {
      if (!isRewarder[rewarders[i]]) {
        revert PLPStaking_NotRewarder();
      }

      EpochFeedableRewarder(rewarders[i]).onHarvest(epochTimestamp, user, receiver);

      unchecked {
        ++i;
      }
    }
  }

  function calculateShare(uint256 epochTimestamp, address rewarder, address user) external view returns (uint256) {
    address[] memory tokens = rewarderStakingTokens[rewarder];
    uint256 share = 0;
    uint256 length = tokens.length;
    for (uint256 i = 0; i < length; ) {
      share += TraderLoyaltyCredit(tokens[i]).balanceOf(epochTimestamp, user);

      unchecked {
        ++i;
      }
    }
    return share;
  }

  function calculateTotalShare(uint256 epochTimestamp, address rewarder) external view returns (uint256) {
    address[] memory tokens = rewarderStakingTokens[rewarder];
    uint256 totalShare = 0;
    uint256 length = tokens.length;
    for (uint256 i = 0; i < length; ) {
      totalShare += TraderLoyaltyCredit(tokens[i]).totalSupplyByEpoch(epochTimestamp);

      unchecked {
        ++i;
      }
    }
    return totalShare;
  }

  function getCurrentEpochTimestamp() public view returns (uint256 epochTimestamp) {
    return (block.timestamp / epochLength) * epochLength;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
