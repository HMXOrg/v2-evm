// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IConfig {
  function glpAddress() external view returns (address);

  function glpManagerAddress() external view returns (address);

  function stkGlpAddress() external view returns (address);

  function gmxRewardRouterV2Address() external view returns (address);
}
