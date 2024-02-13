// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum YieldMode {
  AUTOMATIC,
  VOID,
  CLAIMABLE
}

interface IERC20Rebasing is IERC20 {
  function configure(YieldMode) external returns (uint256);

  function claim(address recipient, uint256 amount) external returns (uint256);

  function getClaimableAmount(address account) external view returns (uint256);
}
