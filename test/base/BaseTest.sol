// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { TestBase } from "forge-std/Base.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

import { MockPyth } from "pyth-sdk-solidity/MockPyth.sol";

import { MockErc20 } from "../mocks/MockErc20.sol";
import { MockCalculator } from "../mocks/MockCalculator.sol";
import { MockOracleMiddleware } from "../mocks/MockOracleMiddleware.sol";

import { Deployment } from "../../script/Deployment.s.sol";
import { StorageDeployment } from "../deployment/StorageDeployment.s.sol";

import { ConfigStorage } from "../../src/storages/ConfigStorage.sol";
import { PerpStorage } from "../../src/storages/PerpStorage.sol";
import { VaultStorage } from "../../src/storages/VaultStorage.sol";

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
  ConfigStorage internal configStorage;
  PerpStorage internal perpStorage;
  VaultStorage internal vaultStorage;

  MockPyth internal mockPyth;
  MockCalculator internal mockCalculator;
  MockOracleMiddleware internal mockOracle;

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
    mockOracle = new MockOracleMiddleware();
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

  // --------- Setup Helpers ---------
  // function setupDefaultUnderlying()
  //   internal
  //   view
  //   returns (address[] memory, PoolConfig.UnderlyingConfig[] memory)
  // {
  //   address[] memory underlyings = new address[](4);
  //   underlyings[0] = address(weth);
  //   underlyings[1] = address(wbtc);
  //   underlyings[2] = address(dai);
  //   underlyings[3] = address(usdc);

  //   PoolConfig.UnderlyingConfig[]
  //     memory underlyingConfigs = new PoolConfig.UnderlyingConfig[](4);
  //   underlyingConfigs[0] = PoolConfig.UnderlyingConfig({
  //     isAccept: true,
  //     decimals: weth.decimals(),
  //     weight: 100
  //   });
  //   underlyingConfigs[1] = PoolConfig.UnderlyingConfig({
  //     isAccept: true,
  //     decimals: wbtc.decimals(),
  //     weight: 100
  //   });
  //   underlyingConfigs[2] = PoolConfig.UnderlyingConfig({
  //     isAccept: true,
  //     decimals: dai.decimals(),
  //     weight: 100
  //   });
  //   underlyingConfigs[3] = PoolConfig.UnderlyingConfig({
  //     isAccept: true,
  //     decimals: usdc.decimals(),
  //     weight: 100
  //   });

  //   return (underlyings, underlyingConfigs);
  // }

  // --------- Test Helpers ---------

  /// @notice Helper function to create a price feed update data.
  /// @dev The price data is in the format of [wethPrice, wbtcPrice, daiPrice, usdcPrice] and in 8 decimals.
  /// @param priceData The price data to create the update data.
  function buildPythUpdateData(
    int64[] memory priceData
  ) internal view returns (bytes[] memory) {
    require(priceData.length == 4, "invalid price data length");
    bytes[] memory priceDataBytes = new bytes[](4);
    for (uint256 i = 1; i <= priceData.length; ) {
      priceDataBytes[i - 1] = mockPyth.createPriceFeedUpdateData(
        bytes32(uint256(i)),
        priceData[i - 1] * 1e8,
        0,
        -8,
        priceData[i - 1] * 1e8,
        0,
        uint64(block.timestamp)
      );
      unchecked {
        ++i;
      }
    }
    return priceDataBytes;
  }
}
