// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

contract MockBalancerVault {
  address[] public poolTokens;
  uint256[] public poolBalances;

  function setParams(address[] memory _poolTokens, uint256[] memory _poolBalances) external {
    poolTokens = _poolTokens;
    poolBalances = _poolBalances;
  }

  function getPoolTokens(
    bytes32 /*poolId*/
  ) external view returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) {
    tokens = poolTokens;
    balances = poolBalances;
    lastChangeBlock = block.timestamp;
  }
}
