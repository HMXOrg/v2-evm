// SPDX-License-Identifier: MIT
//   _   _ __  ____  __
//  | | | |  \/  \ \/ /
//  | |_| | |\/| |\  /
//  |  _  | |  | |/  \
//  |_| |_|_|  |_/_/\_\
//

pragma solidity 0.8.18;

interface ITLCStaking {
  function deposit(address to, uint256 amount) external;

  function withdraw(address to, uint256 amount) external;

  function getUserTokenAmount(uint256 epochTimestamp, address sender) external view returns (uint256);

  function harvest(uint256 startEpochTimestamp, uint256 noOfEpochs, address[] calldata _rewarders) external;

  function harvestToCompounder(
    address user,
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    address[] calldata _rewarders
  ) external;

  function calculateTotalShare(uint256 epochTimestamp) external view returns (uint256);

  function calculateShare(uint256 epochTimestamp, address user) external view returns (uint256);

  function isRewarder(address rewarder) external view returns (bool);

  function addRewarder(address newRewarder) external;

  function setWhitelistedCaller(address _whitelistedCaller) external;

  function removeRewarder(uint256 _removeRewarderIndex) external;
}
