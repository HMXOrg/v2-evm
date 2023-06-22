// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { HmxAccountFactory_Base } from "@hmx-test/account-abstraction/HmxAccountFactory/HmxAccountFactory_Base.t.sol";
import { IEntryPoint } from "@hmx/account-abstraction/interfaces/IEntryPoint.sol";
import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

contract HmxAccountFactory_UpgradeTest is HmxAccountFactory_Base {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenNotOwnerCallUpgrade() external {
    address someRandomUser = makeAddr("some random user");
    address someAccount = makeAddr("some account");

    UUPSUpgradeable[] memory targets = new UUPSUpgradeable[](1);
    targets[0] = UUPSUpgradeable(someAccount);

    vm.prank(someRandomUser);
    vm.expectRevert("Ownable: caller is not the owner");
    hmxAccountFactory.upgrade(targets, address(this));
  }

  function testCorrectness_WhenUpgradeAccount() external {
    address owner = makeAddr("some user");
    uint256 salt = 0;

    // Create an account
    HmxAccount account = hmxAccountFactory.createAccount(owner, salt);

    // Try to upgrade account
    HmxAccount someNewImpl = new HmxAccount(IEntryPoint(makeAddr("some entrypoint")));

    UUPSUpgradeable[] memory targets = new UUPSUpgradeable[](1);
    targets[0] = UUPSUpgradeable(address(account));

    hmxAccountFactory.upgrade(targets, address(someNewImpl));
  }
}
