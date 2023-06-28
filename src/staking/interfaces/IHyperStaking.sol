// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

interface IHyperStaking {
  struct TierConfig {
    uint256 maxCap;
    uint256 multiplier;
  }

  function startHyperEventDepositTimestamp() external view returns (uint256);

  function endHyperEventDepositTimestamp() external view returns (uint256);

  function endHyperEventLockTimestamp() external view returns (uint256);

  function rewarders(uint256 index) external returns (address);

  function removeRewarder(uint256 rewarderIndex) external;

  function setTierConfigs(TierConfig[] memory configs) external;

  function addRewarders(address[] memory newRewarders) external;

  function harvest(address[] memory rewarders) external;

  function deposit(address to, uint256 amount) external;

  function depositHyper(address to, uint256 amount) external;

  function withdraw(uint256 amount) external;

  function harvestToCompounder(address user, address[] memory rewarders) external;

  function calculateTotalShareFromHyperEvent(address rewarder) external view returns (uint256);

  function calculateShareFromHyperEvent(address rewarder, address user) external view returns (uint256);

  function calculateTotalShare(address rewarder) external view returns (uint256);

  function calculateShare(address rewarder, address user) external view returns (uint256);

  function isRewarder(address rewarder) external view returns (bool);

  function setHyperRewarder(address _hyperRewarder) external;
}
