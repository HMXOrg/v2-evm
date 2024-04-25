// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IDistributeSTIPARBStrategy {
  function execute(uint256 _amount, uint256 _expiredAt) external;

  function setWhitelistedExecutor(address _executor, bool _active) external;
}
