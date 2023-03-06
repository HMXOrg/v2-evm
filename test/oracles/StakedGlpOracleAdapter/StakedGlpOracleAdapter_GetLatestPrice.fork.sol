// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Config } from "@config/Config.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/vendors/gmx/IGmxGlpManager.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/stakedGlpOracleAdapter.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";

contract StakedGlpOracleAdapter_GetLatestPriceForkTest is Config, StdAssertions {
  using AddressUtils for address;

  bytes32 public constant sGlpAssetId = "sGLP";
  StakedGlpOracleAdapter stakedGlpOracleAdapter;

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
    assertEq(price, (1e18 * IGmxGlpManager(glpManagerAddress).getAum(true)) / IERC20(glpAddress).totalSupply());
    assertEq(timestamp, block.timestamp);
  }
}
