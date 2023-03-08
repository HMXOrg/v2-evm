// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

interface ITradingStaking {
  function deposit(address to, uint256 marketIndex, uint256 amount) external;

  function withdraw(address to, uint256 marketIndex, uint256 amount) external;

  function getUserTokenAmount(uint256 marketIndex, address sender) external view returns (uint256);

  function getMarketIndexRewarders(uint256 _marketIndex) external view returns (address[] memory);

  function harvest(address[] memory rewarders) external;

  function harvestToCompounder(address user, address[] memory rewarders) external;

  function calculateTotalShare(address rewarder) external view returns (uint256);

  function calculateShare(address rewarder, address user) external view returns (uint256);

  function isRewarder(address rewarder) external view returns (bool);

  function addRewarder(address newRewarder, uint256[] memory _newMarketIndex) external;

  function setWhitelistedCaller(address _whitelistedCaller) external;

  function isMarketIndex(uint256 marketIndex) external returns (bool);

  function removeRewarderForTokenByIndex(uint256 removeRewarderIndex, uint256 _marketIndex) external;

  function marketIndexRewarders(uint256, uint256) external view returns (address);
}
