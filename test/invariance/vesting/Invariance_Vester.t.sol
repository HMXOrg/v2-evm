// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest, MockErc20 } from "@hmx-test/base/BaseTest.sol";
import { Test } from "forge-std/Test.sol";
import { InvariantTest } from "forge-std/InvariantTest.sol";
import { Deployer, IVester } from "@hmx-test/libs/Deployer.sol";
import { VesterHandler } from "@hmx-test/invariance/VesterHandler.t.sol";
import { console2 } from "forge-std/console2.sol";

contract Invariance_Vester is Test, InvariantTest {
  IVester private vester;
  VesterHandler private vesterHandler;
  MockErc20 private hmx;
  MockErc20 private esHmx;
  address private constant vestedEsHmxDestinationAddress = address(888);
  address private constant unusedEsHmxDestinationAddress = address(889);
  uint256 private constant esHmxTotalSupply = 100 ether;
  uint256 private constant hmxTotalSupply = 100 ether;

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

    hmx.mint(address(vester), hmxTotalSupply);
    esHmx.mint(address(vesterHandler), esHmxTotalSupply);

    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = VesterHandler.vestAsNewAccount.selector;
    selectors[1] = VesterHandler.claimFor.selector;
    selectors[2] = VesterHandler.abort.selector;
    selectors[3] = VesterHandler.vestAsExistingAccount.selector;

    targetSelector(FuzzSelector({ addr: address(vesterHandler), selectors: selectors }));
    targetContract(address(vesterHandler));
  }

  /**
   * Invariances
   */

  // esHmx can be at the following addresses
  // - VesterHandler from initial mint
  // - Vester from vesting by users
  // - vestedEsHmxDestinationAddress from vested esHmx
  // - unusedEsHmxDestinationAddress from penalty
  // - each user that has already claimed
  // Balanced from all of these addresses should be equal to the total supply
  function invariant_esHmxSupply() public {
    assertEq(
      esHmx.balanceOf(address(vesterHandler)) +
        esHmx.balanceOf(address(vester)) +
        esHmx.balanceOf(vestedEsHmxDestinationAddress) +
        esHmx.balanceOf(unusedEsHmxDestinationAddress) +
        vesterHandler.ghost_esHmxReturnedToUsers(),
      esHmxTotalSupply
    );
  }

  // All penalty amount of esHmx should go to unusedEsHmxDestinationAddress
  function invariant_penaltyAmount() public {
    assertEq(vesterHandler.ghost_totalPenaltyAmount(), esHmx.balanceOf(address(unusedEsHmxDestinationAddress)));
  }

  // HMX can be at the following address
  // - Vester from initial mint; for users to vest esHMX and redeem into HMX token
  // - Each user that has already claimed
  function invariant_hmxSupply() public {
    assertEq(hmx.balanceOf(address(vester)) + vesterHandler.reduceActors(0, this.accumulateHmxBalance), hmxTotalSupply);
  }

  // No one should have HMX token more than the HMX total supply
  function invariant_assertAccountHmxBalanceLteHmxTotalSupply() public {
    vesterHandler.forEachActor(this.assertAccountHmxBalanceLteHmxTotalSupply);
  }

  // No one should have HMX token more than the max possible HMX balance of that account
  // Max possible HMX balance is calculated from everytime the user called `vestFor`,
  // we will track the `totalUnlockedAmount` which is the amount user will get if
  // they wait until the duration of the vesting without abortion.
  function invariant_assertAccountHmxBalanceLteMaxPossibleHmxAccountBalance() public {
    vesterHandler.forEachActor(this.assertAccountHmxBalanceLteMaxPossibleHmxAccountBalance);
  }

  function invariant_callSummary() external {
    vesterHandler.callSummary();
  }

  /**
   * Internal functions
   */
  function accumulateHmxBalance(uint256 balance, address caller) external view returns (uint256) {
    return balance + hmx.balanceOf(caller);
  }

  function assertAccountHmxBalanceLteHmxTotalSupply(address account) external {
    assertLe(hmx.balanceOf(account), hmx.totalSupply());
  }

  function assertAccountHmxBalanceLteMaxPossibleHmxAccountBalance(address account) external {
    assertLe(hmx.balanceOf(account), vesterHandler.ghost_maxPossibleHmxAccountBalance(account));
  }
}
