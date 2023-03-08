// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { IMultiRewarder } from "./interfaces/IMultiRewarder.sol";

contract TradingStaking is Owned {
  error TradingStaking_UnknownMarketIndex();
  error TradingStaking_InsufficientTokenAmount();
  error TradingStaking_NotRewarder();
  error TradingStaking_NotCompounder();
  error TradingStaking_BadDecimals();
  error TradingStaking_DuplicateStakingToken();

  mapping(uint256 => mapping(address => uint256)) public userTokenAmount;
  mapping(uint256 => uint256) public totalShares;
  mapping(address => bool) public isRewarder;
  mapping(uint256 => bool) public isMarketIndex;
  mapping(uint256 => address[]) public marketIndexRewarders;
  mapping(address => uint256[]) public rewarderMarketIndex;

  address public compounder;

  event LogDeposit(address indexed caller, address indexed user, uint256 marketIndex, uint256 amount);
  event LogWithdraw(address indexed caller, uint256 marketIndex, uint256 amount);
  event LogAddStakingToken(uint256 newMarketIndex, address[] newRewarders);
  event LogAddRewarder(address newRewarder, uint256[] newTokens);
  event LogSetCompounder(address oldCompounder, address newCompounder);

  function addPool(uint256 _newMarketIndex, address[] memory newRewarders) external onlyOwner {
    uint256 length = newRewarders.length;
    for (uint256 i = 0; i < length; ) {
      _updatePool(_newMarketIndex, newRewarders[i]);

      emit LogAddStakingToken(_newMarketIndex, newRewarders);
      unchecked {
        ++i;
      }
    }
  }

  function addRewarder(address newRewarder, uint256[] memory _newMarketIndex) external onlyOwner {
    uint256 length = _newMarketIndex.length;
    for (uint256 i = 0; i < length; ) {
      _updatePool(_newMarketIndex[i], newRewarder);

      emit LogAddRewarder(newRewarder, _newMarketIndex);
      unchecked {
        ++i;
      }
    }
  }

  function removeRewarderForMarketIndexByIndex(uint256 removeRewarderIndex, uint256 _marketIndex) external onlyOwner {
    uint256 _marketIndexLength = marketIndexRewarders[_marketIndex].length;
    address removedRewarder = marketIndexRewarders[_marketIndex][removeRewarderIndex];
    marketIndexRewarders[_marketIndex][removeRewarderIndex] = marketIndexRewarders[_marketIndex][
      _marketIndexLength - 1
    ];
    marketIndexRewarders[_marketIndex].pop();

    uint256 rewarderLength = rewarderMarketIndex[removedRewarder].length;
    for (uint256 i = 0; i < rewarderLength; ) {
      if (rewarderMarketIndex[removedRewarder][i] == _marketIndex) {
        rewarderMarketIndex[removedRewarder][i] = rewarderMarketIndex[removedRewarder][rewarderLength - 1];
        rewarderMarketIndex[removedRewarder].pop();
        if (rewarderLength == 1) isRewarder[removedRewarder] = false;

        break;
      }
      unchecked {
        ++i;
      }
    }
  }

  function _updatePool(uint256 _marketIndex, address newRewarder) internal {
    if (!isDuplicatedRewarder(_marketIndex, newRewarder)) marketIndexRewarders[_marketIndex].push(newRewarder);
    if (!isDuplicatedStakingToken(_marketIndex, newRewarder)) rewarderMarketIndex[newRewarder].push(_marketIndex);

    isMarketIndex[_marketIndex] = true;
    if (!isRewarder[newRewarder]) {
      isRewarder[newRewarder] = true;
    }
  }

  function isDuplicatedRewarder(uint256 _marketIndex, address rewarder) internal view returns (bool) {
    uint256 length = marketIndexRewarders[_marketIndex].length;
    for (uint256 i = 0; i < length; ) {
      if (marketIndexRewarders[_marketIndex][i] == rewarder) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }

  function isDuplicatedStakingToken(uint256 _marketIndex, address rewarder) internal view returns (bool) {
    uint256 length = rewarderMarketIndex[rewarder].length;
    for (uint256 i = 0; i < length; ) {
      if (rewarderMarketIndex[rewarder][i] == _marketIndex) {
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

  function deposit(address to, uint256 _marketIndex, uint256 amount) external {
    if (!isMarketIndex[_marketIndex]) revert TradingStaking_UnknownMarketIndex();

    uint256 length = marketIndexRewarders[_marketIndex].length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = marketIndexRewarders[_marketIndex][i];

      IMultiRewarder(rewarder).onDeposit(to, amount);

      unchecked {
        ++i;
      }
    }

    userTokenAmount[_marketIndex][to] += amount;
    totalShares[_marketIndex] += amount;

    emit LogDeposit(msg.sender, to, _marketIndex, amount);
  }

  function getUserTokenAmount(uint256 _marketIndex, address sender) external view returns (uint256) {
    return userTokenAmount[_marketIndex][sender];
  }

  function withdraw(uint256 _marketIndex, uint256 amount) external {
    _withdraw(_marketIndex, amount);
    emit LogWithdraw(msg.sender, _marketIndex, amount);
  }

  function _withdraw(uint256 _marketIndex, uint256 amount) internal {
    if (!isMarketIndex[_marketIndex]) revert TradingStaking_UnknownMarketIndex();
    if (userTokenAmount[_marketIndex][msg.sender] < amount) revert TradingStaking_InsufficientTokenAmount();

    uint256 length = marketIndexRewarders[_marketIndex].length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = marketIndexRewarders[_marketIndex][i];

      IMultiRewarder(rewarder).onWithdraw(msg.sender, amount);

      unchecked {
        ++i;
      }
    }
    userTokenAmount[_marketIndex][msg.sender] -= amount;
    totalShares[_marketIndex] -= amount;

    emit LogWithdraw(msg.sender, _marketIndex, amount);
  }

  function harvest(address[] memory _rewarders) external {
    _harvestFor(msg.sender, msg.sender, _rewarders);
  }

  function harvestToCompounder(address user, address[] memory _rewarders) external {
    if (compounder != msg.sender) revert TradingStaking_NotCompounder();
    _harvestFor(user, compounder, _rewarders);
  }

  function _harvestFor(address user, address receiver, address[] memory _rewarders) internal {
    uint256 length = _rewarders.length;
    for (uint256 i = 0; i < length; ) {
      if (!isRewarder[_rewarders[i]]) {
        revert TradingStaking_NotRewarder();
      }

      IMultiRewarder(_rewarders[i]).onHarvest(user, receiver);

      unchecked {
        ++i;
      }
    }
  }

  function calculateShare(address rewarder, address user) external view returns (uint256) {
    uint256[] memory marketIndices = rewarderMarketIndex[rewarder];
    uint256 share = 0;
    uint256 length = marketIndices.length;
    for (uint256 i = 0; i < length; ) {
      share += userTokenAmount[marketIndices[i]][user];

      unchecked {
        ++i;
      }
    }
    return share;
  }

  function calculateTotalShare(address rewarder) external view returns (uint256) {
    uint256[] memory marketIndices = rewarderMarketIndex[rewarder];
    uint256 totalShare = 0;
    uint256 length = marketIndices.length;
    for (uint256 i = 0; i < length; ) {
      totalShare += totalShares[marketIndices[i]];

      unchecked {
        ++i;
      }
    }
    return totalShare;
  }
}
