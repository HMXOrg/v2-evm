// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest, MockErc20 } from "@hmx-test/base/BaseTest.sol";
import { Test } from "forge-std/Test.sol";
import { InvariantTest } from "forge-std/InvariantTest.sol";
import { Deployer, IVester } from "@hmx-test/libs/Deployer.sol";
import { VesterHandler } from "@hmx-test/invariance/VesterHandler.t.sol";
import { console } from "forge-std/console.sol";

contract Invariance_Vester is Test, InvariantTest {
  IVester private vester;
  VesterHandler private vesterHandler;
  MockErc20 private hmx;
  MockErc20 private esHmx;
  address private constant vestedEsHmxDestinationAddress = address(888);
  address private constant unusedEsHmxDestinationAddress = address(889);
  uint256 private constant esHmxTotalSupply = 100 ether;

  function setUp() public {
    hmx = new MockErc20("HMX", "HMX", 18);
    esHmx = new MockErc20("esHMX", "esHMX", 18);
    vester = Deployer.deployVester(
      address(this),
      address(esHmx),
      address(hmx),
      vestedEsHmxDestinationAddress,
      unusedEsHmxDestinationAddress
    );

    vesterHandler = new VesterHandler(vester, hmx, esHmx);

    hmx.mint(address(vester), esHmxTotalSupply);
    esHmx.mint(address(vesterHandler), esHmxTotalSupply);

    targetContract(address(vesterHandler));
  }

  function invariant_esHmxShouldBeReceivedByVester() public {
    assertEq(
      esHmx.balanceOf(address(vesterHandler)) +
        esHmx.balanceOf(address(vester)) +
        esHmx.balanceOf(unusedEsHmxDestinationAddress),
      esHmxTotalSupply
    );
  }

  function invariant_penaltyAmount() public {
    assertEq(vesterHandler.ghost_totalPenaltyAmount(), esHmx.balanceOf(address(unusedEsHmxDestinationAddress)));
  }

  function invariant_hmxSupplyShouldBeCorrect() public {
    assertEq(hmx.balanceOf(address(vesterHandler)) + hmx.balanceOf(address(vester)), esHmxTotalSupply);
  }
}
