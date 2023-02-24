// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

interface ITradingStaking {
  function deposit(address _for, uint256 _pid, uint256 _amount) external;

  function withdraw(address _for, uint256 _pid, uint256 _amount) external;

  function poolIdByMarketIndex(uint256 _markerIndex) external returns (uint256 _pid);
}
