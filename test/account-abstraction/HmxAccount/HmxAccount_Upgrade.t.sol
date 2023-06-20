// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { HmxAccount_Base } from "@hmx-test/account-abstraction/HmxAccount/HmxAccount_Base.t.sol";
import { IEntryPoint } from "@hmx/account-abstraction/interfaces/IEntryPoint.sol";
import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

contract HmxAccount_UpgradeTest is HmxAccount_Base {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenOwnerTryToUpgrade() external {
    HmxAccount newHmxAccount = new HmxAccount(IEntryPoint(makeAddr("entryPoint")));

    vm.expectRevert("!factory");
    hmxAccount.upgradeTo(address(newHmxAccount));
  }
}
