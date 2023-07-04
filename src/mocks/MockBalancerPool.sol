// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

contract MockBalancerPool {
  uint256[] public normalizedWeights;
  uint256 public swapFeePercentage;
  address public vault;

  function setNormalizedWeights(uint256[] memory _normalizedWeights) external {
    normalizedWeights = _normalizedWeights;
  }

  function getNormalizedWeights() external view returns (uint256[] memory) {
    return normalizedWeights;
  }

  function setSwapFeePercentage(uint256 _swapFeePercentage) external {
    swapFeePercentage = _swapFeePercentage;
  }

  function getSwapFeePercentage() public view returns (uint256) {
    return swapFeePercentage;
  }

  function getPoolId() public pure returns (bytes32) {
    return "";
  }

  function setVault(address _vault) external {
    vault = _vault;
  }

  function getVault() public view returns (address) {
    return vault;
  }
}
