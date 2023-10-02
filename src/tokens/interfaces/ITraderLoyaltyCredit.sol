// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ITraderLoyaltyCredit is IERC20Upgradeable {
  error TLC_NotMinter();
  error TLC_AllowanceBelowZero();
  error TLC_TransferFromZeroAddress();
  error TLC_TransferToZeroAddress();
  error TLC_TransferAmountExceedsBalance();
  error TLC_MintToZeroAddress();
  error TLC_BurnFromZeroAddress();
  error TLC_BurnAmountExceedsBalance();
  error TLC_ApproveFromZeroAddress();
  error TLC_ApproveToZeroAddress();
  error TLC_InsufficientAllowance();

  function mint(address account, uint256 amount) external;

  function getCurrentEpochTimestamp() external view returns (uint256 epochTimestamp);

  function setMinter(address _minter, bool _mintable) external;

  function balanceOf(uint256 epochTimestamp, address account) external view returns (uint256);

  function totalSupplyByEpoch(uint256 epochTimestamp) external view returns (uint256);
}
