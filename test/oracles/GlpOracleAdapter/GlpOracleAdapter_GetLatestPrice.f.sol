// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Config } from "@config/Config.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/vendors/gmx/IGmxGlpManager.sol";
import { GlpOracleAdapter } from "@hmx/oracles/GlpOracleAdapter.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";

contract GlpOracleAdapter_GetLatestPriceForkTest is Config, StdAssertions {
  using AddressUtils for address;

  GlpOracleAdapter glpOracleAdapter;

  function setUp() public {
    glpOracleAdapter = new GlpOracleAdapter(IERC20(glpAddress), IGmxGlpManager(glpManagerAddress));
  }

  function testCorrectness_WhenGetGlpLatestMaxPrice() external {
    (uint256 price, uint256 timestamp) = glpOracleAdapter.getLatestPrice(glpAddress.toBytes32(), true, 0);
    assertEq(price, (1e18 * IGmxGlpManager(glpManagerAddress).getAum(true)) / IERC20(glpAddress).totalSupply());
    assertEq(timestamp, block.timestamp);
  }

  function testCorrectness_WhenGetGlpLatestMinPrice() external {
    (uint256 price, uint256 timestamp) = glpOracleAdapter.getLatestPrice(glpAddress.toBytes32(), false, 0);
    assertEq(price, (1e18 * IGmxGlpManager(glpManagerAddress).getAum(true)) / IERC20(glpAddress).totalSupply());
    assertEq(timestamp, block.timestamp);
  }
}
