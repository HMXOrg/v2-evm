// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IGmxGlpManager {
  function getAum(bool useMaxPrice) external view returns (uint256);

  function getAums() external view returns (uint256[] memory);

  function getAumInUsdg(bool useMaxPrice) external view returns (uint256);

  function addLiquidityForAccount(
    address _fundingAccount,
    address _account,
    address _token,
    uint256 _amount,
    uint256 _minUsdg,
    uint256 _minGlp
  ) external returns (uint256);
}
