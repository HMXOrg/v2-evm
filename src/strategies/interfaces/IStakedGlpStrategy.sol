// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IStakedGlpStrategy {
  function execute() external;

  function setWhiteListExecutor(address _executor, bool _active) external;
}
