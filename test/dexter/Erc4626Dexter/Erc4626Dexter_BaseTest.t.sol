// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Erc4626Dexter } from "@hmx/extensions/dexters/Erc4626Dexter.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract Erc4626Dexter_BaseTest is BaseTest {
  Erc4626Dexter internal erc4626Dexter;

  function setUp() public virtual {
    erc4626Dexter = Erc4626Dexter(address(Deployer.deployErc4626Dexter()));

    erc4626Dexter.setSupportedToken(address(ybeth), true);
    erc4626Dexter.setSupportedToken(address(ybusdb), true);
  }
}
