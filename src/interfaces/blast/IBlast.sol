// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

enum YieldMode {
  AUTOMATIC,
  VOID,
  CLAIMABLE
}

interface IBlast {
  function configureClaimableYield() external;

  function claimAllYield(address contractAddress, address receipientOfYield) external returns (uint256);

  function readClaimableYield(address contractAddress) external view returns (uint256);
}
