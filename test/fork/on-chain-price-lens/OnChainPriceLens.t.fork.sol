// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// HMX tests
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { WstEthUsdPriceAdapter } from "@hmx/oracles/adapters/WstEthUsdPriceAdapter.sol";
import { GlpPriceAdapter } from "src/oracles/adapters/GlpPriceAdapter.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";
import { IPriceAdapter } from "@hmx/oracles/interfaces/IPriceAdapter.sol";
import { OnChainPriceLens } from "@hmx/oracles/OnChainPriceLens.sol";
import { EcoPythCalldataBuilder } from "@hmx/oracles/EcoPythCalldataBuilder.sol";
import { UnsafeEcoPythCalldataBuilder } from "@hmx/oracles/UnsafeEcoPythCalldataBuilder.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";

contract OnChainPriceLens_ForkTest is TestBase, Cheats, StdAssertions, StdCheatsSafe {
  WstEthUsdPriceAdapter internal wstEthUsdPriceAdapter;
  GlpPriceAdapter internal glpPriceAdapter;
  OnChainPriceLens internal onChainPriceLens;
  EcoPythCalldataBuilder internal ecoPythCalldataBuilder;
  UnsafeEcoPythCalldataBuilder internal unsafeEcoPythCalldataBuilder;
  address constant wstEthPriceFeed = 0xb523AE262D20A936BC152e6023996e46FDC2A95D;
  address constant ethUsdPriceFeed = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 128556281);

    wstEthUsdPriceAdapter = new WstEthUsdPriceAdapter(
      AggregatorV3Interface(wstEthPriceFeed),
      AggregatorV3Interface(ethUsdPriceFeed)
    );

    glpPriceAdapter = new GlpPriceAdapter(ForkEnv.sGlp, ForkEnv.glpManager);

    onChainPriceLens = new OnChainPriceLens();

    bytes32[] memory priceIds = new bytes32[](2);
    priceIds[0] = "GLP";
    priceIds[1] = "wstETH";
    IPriceAdapter[] memory priceAdapters = new IPriceAdapter[](2);
    priceAdapters[0] = glpPriceAdapter;
    priceAdapters[1] = wstEthUsdPriceAdapter;
    onChainPriceLens.setPriceAdapters(priceIds, priceAdapters);

    ecoPythCalldataBuilder = new EcoPythCalldataBuilder(ForkEnv.ecoPyth2, onChainPriceLens);
    unsafeEcoPythCalldataBuilder = new UnsafeEcoPythCalldataBuilder(ForkEnv.ecoPyth2, onChainPriceLens);

    vm.startPrank(ForkEnv.multiSig);
    ForkEnv.ecoPyth2.insertAssetId("wstETH");
    vm.stopPrank();
  }

  function testCorrectness_WstEthUsdPriceAdapter() external {
    uint256 wstEthUsdPrice = wstEthUsdPriceAdapter.getPrice();
    assertEq(wstEthUsdPrice, 1857.620239758899083350 ether);
  }

  function testCorrectness_GlpPriceAdapter() external {
    uint256 glpPrice = glpPriceAdapter.getPrice();
    assertEq(glpPrice, 0.948534563693319704 ether);
  }

  function testCorrectness_OnChainPriceLens_getPrice() external {
    uint256 wstEthUsdPrice = onChainPriceLens.getPrice("wstETH");
    assertEq(wstEthUsdPrice, 1857.620239758899083350 ether);

    uint256 glpPrice = onChainPriceLens.getPrice("GLP");
    assertEq(glpPrice, 0.948534563693319704 ether);
  }

  function testCorrectness_EcoPythCalldataBuilder_build() external {
    IEcoPythCalldataBuilder.BuildData[] memory _data = new IEcoPythCalldataBuilder.BuildData[](4);
    _data[0] = IEcoPythCalldataBuilder.BuildData({
      assetId: "ETH",
      priceE8: 1633.61 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[1] = IEcoPythCalldataBuilder.BuildData({
      assetId: "GLP",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[2] = IEcoPythCalldataBuilder.BuildData({
      assetId: "BTC",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[3] = IEcoPythCalldataBuilder.BuildData({
      assetId: "wstETH",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });

    unsafeEcoPythCalldataBuilder.build(_data);
  }
}
