// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGmxVault {
  function whitelistedTokens(address token) external view returns (bool);
}
