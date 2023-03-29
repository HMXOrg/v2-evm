// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IVester } from "@hmx-test/libs/Deployer.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

contract VesterHandler is CommonBase, StdCheats, StdUtils {
  IVester private vester;
  MockErc20 private hmx;
  MockErc20 private esHmx;
  uint256 public ghost_totalUnlockedAmount;
  uint256 public ghost_amount;
  uint256 public ghost_totalPenaltyAmount;
  uint256 public ghost_hmxToBeClaimed;
  uint256 public ghost_esHmxReturnedToUsers;

  constructor(IVester _vester, MockErc20 _hmx, MockErc20 _esHmx) {
    vester = _vester;
    hmx = _hmx;
    esHmx = _esHmx;
  }

  function vestFor(address account, uint256 amount, uint256 duration) public {
    amount = bound(amount, 0, esHmx.balanceOf(address(this)));
    esHmx.approve(address(vester), type(uint256).max);
    vester.vestFor(account, amount, duration);
    (, , , , , , , uint256 totalUnlockedAmount) = vester.items(vester.nextItemId() - 1);

    ghost_amount += amount;
    ghost_totalUnlockedAmount += totalUnlockedAmount;
    ghost_totalPenaltyAmount += amount - totalUnlockedAmount;
  }

  function abort(uint256 itemIndex) public {
    itemIndex = bound(itemIndex, 0, vester.nextItemId());
    (address owner, , , , , , , uint256 totalUnlockedAmount) = vester.items(itemIndex);
    vm.prank(owner);
    uint256 esHmxBalanceBefore = esHmx.balanceOf(owner);
    vester.abort(itemIndex);
    ghost_esHmxReturnedToUsers += esHmx.balanceOf(owner) - esHmxBalanceBefore;
    ghost_totalUnlockedAmount -= totalUnlockedAmount;
  }

  function claimFor(address someone, uint256 itemIndex, uint256 duration) public {
    itemIndex = bound(itemIndex, 0, vester.nextItemId());
    (address owner, , , uint256 amount, , , uint256 lastClaimTime, ) = vester.items(itemIndex);
    vm.warp(block.timestamp + duration);
    uint256 hmxBalanceBefore = hmx.balanceOf(owner);
    vm.prank(someone);
    vester.claimFor(owner, itemIndex);
    ghost_hmxToBeClaimed += hmx.balanceOf(owner) - hmxBalanceBefore;
  }

  function warp(uint256 duration) public {
    vm.warp(block.timestamp + duration);
  }
}
