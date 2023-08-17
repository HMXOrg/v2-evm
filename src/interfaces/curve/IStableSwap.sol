// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IStableSwap {
  function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256 amount_out);

  function coins(uint256 i) external view returns (address);
}
