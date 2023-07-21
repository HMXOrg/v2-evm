// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ISwitchCollateralExt {
  function run(address _tokenIn, address _tokenOut, uint256 _amountIn) external returns (uint256);
}
