// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IConfig {
  function glpAddress() external view returns (address);

  function glpManagerAddress() external view returns (address);

  function sGlpAddress() external view returns (address);

  function gmxRewardRouterV2Address() external view returns (address);

  function glpFeeTrackerAddress() external view returns (address);

  function pythAddress() external view returns (address);

  function wethAddress() external view returns (address);
}
