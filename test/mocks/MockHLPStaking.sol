// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.
import { HLP } from "@hmx/contracts/HLP.sol";

pragma solidity 0.8.18;

contract MockHLPStaking {
  HLP public hlp;
  mapping(address user => uint256 balance) public userTokenAmount;

  constructor(address _hlp) {
    hlp = HLP(_hlp);
  }

  function startHyperEventDepositTimestamp() external pure returns (uint256) {
    return 0;
  }

  function endHyperEventDepositTimestamp() external pure returns (uint256) {
    return 0;
  }

  function endHyperEventLockTimestamp() external pure returns (uint256) {
    return 0;
  }

  function deposit(address to, uint256 amount) external {
    hlp.transferFrom(msg.sender, address(this), amount);

    userTokenAmount[to] += amount;
  }

  function depositSurge(address to, uint256 amount) external {
    hlp.transferFrom(msg.sender, address(this), amount);

    userTokenAmount[to] += amount;
  }

  function withdraw(uint256 amount) external {
    userTokenAmount[msg.sender] -= amount;

    hlp.transfer(msg.sender, amount);
  }
}
