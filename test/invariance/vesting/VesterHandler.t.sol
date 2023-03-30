// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IVester } from "@hmx-test/libs/Deployer.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
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

  function vestAsNewAccount(uint256 amount, uint256 duration) public createActor countCall("vestAsNewAccount") {
    amount = bound(amount, 1, esHmx.balanceOf(address(this)));
    duration = bound(duration, 1, 365 days);

    _vest(currentActor, amount, duration);
  }

  function vestAsExistingAccount(
    uint256 accountIndexSeed,
    uint256 amount,
    uint256 duration
  ) public useActor(accountIndexSeed) countCall("vestAsExistingAccount") {
    amount = bound(amount, 1, esHmx.balanceOf(address(this)));
    duration = bound(duration, 1, 365 days);

    _vest(currentActor, amount, duration);
  }

  function _vest(address account, uint256 amount, uint256 duration) internal {
    esHmx.approve(address(vester), type(uint256).max);
    uint256 nextItemId = vester.nextItemId();
    vester.vestFor(account, amount, duration);
    (, , , , , , , uint256 totalUnlockedAmount) = vester.items(nextItemId);

    ghost_amount += amount;
    ghost_totalUnlockedAmount += totalUnlockedAmount;
    ghost_totalPenaltyAmount += amount - totalUnlockedAmount;
    ghost_maxPossibleHmxAccountBalance[account] += totalUnlockedAmount;

    console2.log("hmxBalance", hmx.balanceOf(account));
    console2.log("ghost_maxPossibleHmxAccountBalance[account]", ghost_maxPossibleHmxAccountBalance[account]);
  }

  function abort(uint256 itemIndex, uint256 duration) public createActor countCall("abort") {
    itemIndex = bound(itemIndex, 0, vester.nextItemId() - 1);

    (address owner, , , , uint256 startTime, uint256 endTime, , uint256 totalUnlockedAmount) = vester.items(itemIndex);

    duration = bound(duration, 0, endTime - startTime + 1);
    vm.warp(block.timestamp + duration);

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

  function claimFor(
    address someone,
    uint256 itemIndex,
    uint256 duration,
    uint256 duration2
  ) public createActor countCall("claimFor") {
    itemIndex = bound(itemIndex, 0, vester.nextItemId() - 1);

    (address owner, , , uint256 amount, uint256 startTime, uint256 endTime, , ) = vester.items(itemIndex);

    duration = bound(duration, 0, endTime - startTime + 1);
    vm.warp(block.timestamp + duration);
    uint256 hmxBalanceBefore = hmx.balanceOf(owner);
    vm.prank(someone);
    vester.claimFor(owner, itemIndex);
    ghost_hmxToBeClaimed += hmx.balanceOf(owner) - hmxBalanceBefore;

    // Double call to test double claim
    duration2 = bound(duration, 0, endTime - startTime + 1);
    vm.warp(block.timestamp + duration2);
    vester.claimFor(owner, itemIndex);

    console2.log("hmxBalance", hmx.balanceOf(owner));
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

  function callSummary() external view {
    console2.log("Call summary:");
    console2.log("-------------------");
    console2.log("vestAsNewAccount", calls["vestAsNewAccount"]);
    console2.log("vestAsExistingAccount", calls["vestAsExistingAccount"]);
    console2.log("abort", calls["abort"]);
    console2.log("claimFor", calls["claimFor"]);
    console2.log("-------------------");
  }
}
