// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IReinvestNonHlpTokenStrategy {
  struct ExecuteParams {
    address token;
    uint256 amount;
    uint256 minAmountOutMinUSD;
    uint256 minAmountOutMinGlp;
  }

  function execute() external;

  function setWhiteListExecutor(address _executor, bool _active) external;

  function setStrategyBPS(uint16 _newStrategyBps) external;
}
