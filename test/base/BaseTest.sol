// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { TestBase } from "forge-std/Base.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

import { MockPyth } from "pyth-sdk-solidity/MockPyth.sol";

import { MockErc20 } from "../mocks/MockErc20.sol";
import { MockCalculator } from "../mocks/MockCalculator.sol";

import { Deployment } from "../../script/Deployment.s.sol";
import { StorageDeployment } from "../deployment/StorageDeployment.s.sol";

abstract contract BaseTest is
  TestBase,
  Deployment,
  StorageDeployment,
  StdAssertions,
  StdCheatsSafe
{
  address internal ALICE;
  address internal BOB;
  address internal CAROL;
  address internal DAVE;

  // storages
  address internal configStorage;
  address internal perpStorage;
  address internal vaultStorage;

  MockPyth internal mockPyth;
  MockCalculator internal mockCalculator;

  MockErc20 internal weth;
  MockErc20 internal wbtc;
  MockErc20 internal dai;
  MockErc20 internal usdc;

  MockErc20 internal bad;

  bytes32 internal constant wethPriceId =
    0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 internal constant wbtcPriceId =
    0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 internal constant daiPriceId =
    0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 internal constant usdcPriceId =
    0x0000000000000000000000000000000000000000000000000000000000000004;

  constructor() {
    // Creating a mock Pyth instance with 60 seconds valid time period
    // and 1 wei for updating price.
    mockPyth = new MockPyth(60, 1);

    ALICE = makeAddr("Alice");
    BOB = makeAddr("BOB");
    CAROL = makeAddr("CAROL");
    DAVE = makeAddr("DAVE");

    weth = deployMockErc20("Wrapped Ethereum", "WETH", 18);
    wbtc = deployMockErc20("Wrapped Bitcoin", "WBTC", 8);
    dai = deployMockErc20("DAI Stablecoin", "DAI", 18);
    usdc = deployMockErc20("USD Coin", "USDC", 6);
    bad = deployMockErc20("Bad Coin", "BAD", 2);

    configStorage = deployConfigStorage();
    perpStorage = deployPerpStorage();
    vaultStorage = deployVaultStorage();

    mockCalculator = new MockCalculator();
  }

  // --------- Deploy Helpers ---------
  function deployMockErc20(
    string memory name,
    string memory symbol,
    uint8 decimals
  ) internal returns (MockErc20) {
    return new MockErc20(name, symbol, decimals);
  }

  function deployPerp88v2()
    internal
    returns (Deployment.DeployReturnVars memory)
  {
    DeployLocalVars memory deployLocalVars = DeployLocalVars({
      pyth: mockPyth,
      defaultOracleStaleTime: 300
    });
    return deploy(deployLocalVars);
  }
}
