// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";

import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

import { console } from "forge-std/console.sol";
import { stdJson } from "forge-std/StdJson.sol";

contract StakedGlpOracleAdapter_GetLatestPrice is TestBase, StdAssertions, StdCheatsSafe {
  bytes32 public constant sGlpAssetId = "sGLP";
  StakedGlpOracleAdapter stakedGlpOracleAdapter;

  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));
  address public constant glpAddress = 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258;
  address public constant glpManagerAddress = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;

  function setUp() public {
    stakedGlpOracleAdapter = new StakedGlpOracleAdapter(
      IERC20(glpAddress),
      IGmxGlpManager(glpManagerAddress),
      sGlpAssetId
    );
  }

  function testCorrectness_WhenGetGlpLatestMaxPrice() external {
    (uint256 price, uint256 timestamp) = stakedGlpOracleAdapter.getLatestPrice(sGlpAssetId, true, 0);
    assertEq(price, (1e18 * IGmxGlpManager(glpManagerAddress).getAum(true)) / IERC20(glpAddress).totalSupply());
    assertEq(timestamp, block.timestamp);
  }

  function testCorrectness_WhenGetGlpLatestMinPrice() external {
    (uint256 price, uint256 timestamp) = stakedGlpOracleAdapter.getLatestPrice(sGlpAssetId, false, 0);
    assertEq(price, (1e18 * IGmxGlpManager(glpManagerAddress).getAum(false)) / IERC20(glpAddress).totalSupply());
    assertEq(timestamp, block.timestamp);
  }
}
