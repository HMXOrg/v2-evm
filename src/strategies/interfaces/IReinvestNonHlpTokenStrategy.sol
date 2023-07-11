// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IReinvestNonHlpTokenStrategy {
  struct ExecuteParams {
    address token;
    uint256 amount;
    uint256 minAmountOutUSD;
    uint256 minAmountOutGlp;
  }

  function execute(ExecuteParams[] calldata _params) external;

  function setWhiteListExecutor(address _executor, bool _active) external;

  function setStrategyBPS(uint16 _newStrategyBps) external;
}
