// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewarder {
  function name() external view returns (string memory);

  function onDeposit(uint256 pid, address user, uint256 rewardTokenAmount, uint256 newStakeTokenAmount) external;

  function onWithdraw(uint256 pid, address user, uint256 rewardTokenAmount, uint256 newStakeTokenAmount) external;

  function onHarvest(uint256 pid, address user, uint256 rewardTokenAmount) external;

  function pendingTokens(
    uint256 pid,
    address user,
    uint256 rewardTokenAmount
  ) external view returns (IERC20[] memory, uint256[] memory);
}
