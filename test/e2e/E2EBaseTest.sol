// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { TestBase } from "forge-std/Base.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

// import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
// import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { MockPyth } from "pyth-sdk-solidity/MockPyth.sol";

abstract contract E2EBaseTest is TestBase, StdAssertions, StdCheatsSafe {
  address internal ALICE;
  address internal BOB;
  address internal CAROL;
  address internal DAVE;

  /* TOKENS */

  //LP tokens
  ERC20 glp;
  ERC20 plp;

  // UNDERLYING ARBRITRUM GLP => ETH WBTC LINK UNI USDC USDT DAI FRAX
  ERC20 weth; //for native
  ERC20 wbtc; // decimals 8
  ERC20 usdc; // decimals 6
  ERC20 usdt; // decimals 6
  ERC20 dai; // decimals 18

  ERC20 gmx; //decimals 18

  address jpy = address(0);

  /* MARKET */

  // assetIds
  bytes32 internal constant wethAssetId = "weth";
  bytes32 internal constant wbtcAssetId = "wbtc";

  bytes32 internal constant gmxAssetId = "gmx";

  bytes32 internal constant jpyAssetId = "jpy";

  /* PYTH */
  MockPyth internal mockPyth;

  constructor() {
    // deploy pyth adapter
    // deploy stakedGLPOracleAdapter
    // deploy oracleMiddleWare
    // deploy configStorage
    // deploy perpStorage
    // dpeloy vaultStorage
    // deploy plp
    // deploy calculator
    // deploy handler and service
    /* configStorage */
    // serviceExecutor
    // calculator
    // oracle
    // plp
    // weth
  }
}
