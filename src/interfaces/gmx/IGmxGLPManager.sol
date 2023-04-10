// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IGmxGlpManager {
  function getAum(bool useMaxPrice) external view returns (uint256);

  function getAumInUsdg(bool useMaxPrice) external view returns (uint256);
}
