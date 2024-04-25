// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { CIXPriceAdapter } from "@hmx/oracles/CIXPriceAdapter.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract CIXPriceAdapter_BaseTest is BaseTest {
  CIXPriceAdapter cixPriceAdapter;

  function setUp() public virtual {
    cixPriceAdapter = CIXPriceAdapter(address(Deployer.deployCIXPriceAdapter()));
  }
}
