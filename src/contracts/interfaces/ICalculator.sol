// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICalculator {
  function getAUM() external returns (uint256);

  function getPLPPrice(uint256 aum, uint256 supply) external returns (uint256);

  function getMintAmount() external view returns (uint256);

  function convertTokenDecimals(
    uint256 fromTokenDecimals,
    uint256 toTokenDecimals,
    uint256 amount
  ) external pure returns (uint256);
}
