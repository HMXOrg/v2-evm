// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { IERC20Upgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

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
