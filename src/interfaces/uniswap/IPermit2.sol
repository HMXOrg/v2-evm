// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPermit2 {
  function allowance(address user, address token, address spender) external view returns (uint160, uint48, uint48);

  function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}
