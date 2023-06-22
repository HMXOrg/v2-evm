// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract StakedGlpOracleAdapter_BaseTest is BaseTest {
  IOracleAdapter internal stakedGlpOracleAdapter;

  function setUp() public virtual {
    stakedGlpOracleAdapter = Deployer.deployStakedGlpOracleAdapter(
      address(proxyAdmin),
      IERC20Upgradeable(address(sglp)),
      mockGlpManager,
      sglpAssetId
    );
  }
}
