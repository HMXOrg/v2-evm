// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IConvertedGlpStrategy {
  function execute(address _tokenOut, uint256 _amount) external returns (uint256 _amountOut);

  function setWhiteListExecutor(address _executor, bool _active) external;
}
