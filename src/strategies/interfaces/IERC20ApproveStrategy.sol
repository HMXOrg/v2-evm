// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IERC20ApproveStrategy {
  function execute(address _token, address _spender, uint256 _amount) external;

  function setWhitelistedExecutor(address _executor, bool _active) external;
}
