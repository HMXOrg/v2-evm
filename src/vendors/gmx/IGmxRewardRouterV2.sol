// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGmxRewardRouterV2 {
  function mintAndStakeGlp(
    address _token,
    uint256 _amount,
    uint256 _minUsdg,
    uint256 _minGlp
  ) external returns (uint256);
}
