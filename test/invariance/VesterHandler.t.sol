// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IVester } from "@hmx-test/libs/Deployer.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { AddressSet, LibAddressSet } from "test/libs/AddressSet.sol";

contract VesterHandler is CommonBase, StdCheats, StdUtils {
  using LibAddressSet for AddressSet;

  IVester private vester;
  MockErc20 private hmx;
  MockErc20 private esHmx;
  uint256 public ghost_totalUnlockedAmount;
  uint256 public ghost_amount;
  uint256 public ghost_totalPenaltyAmount;
  uint256 public ghost_hmxToBeClaimed;
  uint256 public ghost_esHmxReturnedToUsers;
  mapping(address => uint256) public ghost_maxPossibleHmxAccountBalance;

  AddressSet internal _actors;
  address internal currentActor;

  mapping(bytes32 => uint256) public calls;

  modifier createActor() {
    currentActor = msg.sender;
    _actors.add(msg.sender);
    _;
  }

  modifier useActor(uint256 actorIndexSeed) {
    currentActor = _actors.rand(actorIndexSeed);
    _;
  }

  modifier countCall(bytes32 key) {
    calls[key]++;
    _;
  }

  constructor(IVester _vester, MockErc20 _hmx, MockErc20 _esHmx) {
    vester = _vester;
    hmx = _hmx;
    esHmx = _esHmx;
  }

  function vestFor(uint256 amount, uint256 duration) public createActor countCall("vestFor") {
    amount = bound(amount, 0, esHmx.balanceOf(address(this)));
    esHmx.approve(address(vester), type(uint256).max);
    vester.vestFor(currentActor, amount, duration);
    (, , , , , , , uint256 totalUnlockedAmount) = vester.items(vester.nextItemId() - 1);

    ghost_amount += amount;
    ghost_totalUnlockedAmount += totalUnlockedAmount;
    ghost_totalPenaltyAmount += amount - totalUnlockedAmount;
    ghost_maxPossibleHmxAccountBalance[currentActor] += totalUnlockedAmount;
  }

  function abort(uint256 itemIndex, uint256 duration) public countCall("abort") {
    vm.warp(block.timestamp + duration);
    itemIndex = bound(itemIndex, 0, vester.nextItemId() - 1);
    (address owner, , , , , , , uint256 totalUnlockedAmount) = vester.items(itemIndex);
    uint256 esHmxBalanceBefore = esHmx.balanceOf(owner);
    vm.prank(owner);
    vester.abort(itemIndex);
    ghost_esHmxReturnedToUsers += esHmx.balanceOf(owner) - esHmxBalanceBefore;
    ghost_totalUnlockedAmount -= totalUnlockedAmount;

    // Double call here to test if double abort is possible
    vm.warp(block.timestamp + duration);
    vm.prank(owner);
    vester.abort(itemIndex);
  }

  function claimFor(address someone, uint256 itemIndex, uint256 duration) public countCall("claimFor") {
    itemIndex = bound(itemIndex, 0, vester.nextItemId() - 1);
    (address owner, , , uint256 amount, , , uint256 lastClaimTime, ) = vester.items(itemIndex);
    vm.warp(block.timestamp + duration);
    uint256 hmxBalanceBefore = hmx.balanceOf(owner);
    vm.prank(someone);
    vester.claimFor(owner, itemIndex);
    ghost_hmxToBeClaimed += hmx.balanceOf(owner) - hmxBalanceBefore;

    // Double call to test double claim
    vm.warp(block.timestamp + duration);
    vester.claimFor(owner, itemIndex);
  }

  function forEachActor(function(address) external func) public {
    return _actors.forEach(func);
  }

  function reduceActors(
    uint256 acc,
    function(uint256, address) external returns (uint256) func
  ) public returns (uint256) {
    return _actors.reduce(acc, func);
  }

  function actors() external view returns (address[] memory) {
    return _actors.addrs;
  }

  // function callSummary() external view {
  //   console.log("Call summary:");
  //   console.log("-------------------");
  //   console.log("deposit", calls["deposit"]);
  //   console.log("withdraw", calls["withdraw"]);
  //   console.log("sendFallback", calls["sendFallback"]);
  //   console.log("approve", calls["approve"]);
  //   console.log("transfer", calls["transfer"]);
  //   console.log("transferFrom", calls["transferFrom"]);
  //   console.log("forcePush", calls["forcePush"]);
  //   console.log("-------------------");

  //   console.log("Zero withdrawals:", ghost_zeroWithdrawals);
  //   console.log("Zero transferFroms:", ghost_zeroTransferFroms);
  //   console.log("Zero transfers:", ghost_zeroTransfers);
  // }
}
