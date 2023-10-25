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
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

/// HMX tests
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { WstEthUsdPriceAdapter } from "@hmx/oracles/adapters/WstEthUsdPriceAdapter.sol";
import { GlpPriceAdapter } from "src/oracles/adapters/GlpPriceAdapter.sol";
import { HlpPriceAdapter } from "src/oracles/adapters/HlpPriceAdapter.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";
import { ICalcPriceAdapter } from "@hmx/oracles/interfaces/ICalcPriceAdapter.sol";
import { OnChainPriceLens } from "@hmx/oracles/OnChainPriceLens.sol";
import { CalcPriceLens } from "@hmx/oracles/CalcPriceLens.sol";
import { EcoPythCalldataBuilder3 } from "@hmx/oracles/EcoPythCalldataBuilder3.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";
import { GmPriceAdapter } from "@hmx/oracles/adapters/GmPriceAdapter.sol";
import { IGmxV2Reader } from "@hmx/interfaces/gmxV2/IGmxV2Reader.sol";

contract EcoPythCalldataBuilder3_ForkTest is ForkEnv, Cheats {
  uint256 constant MAX_DIFF = 0.001 ether; // 0.1 %

  CalcPriceLens internal calcPriceLens;
  EcoPythCalldataBuilder3 internal ecoPythCalldataBuilder;
  GmPriceAdapter internal gmBtcUsdPriceAdapter;
  GmPriceAdapter internal gmEthUsdPriceAdapter;

  function setUp() external {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 142248340);

    calcPriceLens = new CalcPriceLens();
    _setupGmPriceAdapters();
    _setupCalcPriceLens();

    ecoPythCalldataBuilder = new EcoPythCalldataBuilder3(
      ForkEnv.ecoPyth2,
      ForkEnv.onChainPriceLens,
      calcPriceLens,
      false
    );
  }

  function _setupGmPriceAdapters() internal {
    gmBtcUsdPriceAdapter = new GmPriceAdapter(
      ForkEnv.gmxV2Reader,
      address(ForkEnv.gmxV2DataStore),
      address(ForkEnv.gmBTCUSD),
      0x47904963fc8b2340414262125aF798B9655E58Cd, // BTCUSD index token
      8,
      address(ForkEnv.wbtc),
      8,
      address(ForkEnv.usdc),
      6,
      1,
      1,
      2
    );

    gmEthUsdPriceAdapter = new GmPriceAdapter(
      ForkEnv.gmxV2Reader,
      address(ForkEnv.gmxV2DataStore),
      address(ForkEnv.gmETHUSD),
      address(ForkEnv.weth),
      18,
      address(ForkEnv.weth),
      18,
      address(ForkEnv.usdc),
      6,
      0,
      0,
      2
    );
  }

  function _setupCalcPriceLens() internal {
    bytes32[] memory priceIds = new bytes32[](2);
    priceIds[0] = "GM-BTCUSD";
    priceIds[1] = "GM-ETHUSD";
    ICalcPriceAdapter[] memory priceAdapters = new ICalcPriceAdapter[](2);
    priceAdapters[0] = gmBtcUsdPriceAdapter;
    priceAdapters[1] = gmEthUsdPriceAdapter;
    calcPriceLens.setPriceAdapters(priceIds, priceAdapters);
  }

  function testCorrectness_getGmTokenPrice() external {
    IEcoPythCalldataBuilder3.BuildData[] memory buildData = new IEcoPythCalldataBuilder3.BuildData[](38);
    buildData[0] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ETH",
      priceE8: 1600.2925 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[1] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BTC",
      priceE8: 29628.25620309 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[2] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "USDC",
      priceE8: 0.99981427 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });

    uint256 gmBtcPrice = gmBtcUsdPriceAdapter.getPrice(buildData);
    uint256 gmEthPrice = gmEthUsdPriceAdapter.getPrice(buildData);

    assertApproxEqRel(gmBtcPrice, 1.042 * 1e18, MAX_DIFF);
    assertApproxEqRel(gmEthPrice, 0.93 * 1e18, MAX_DIFF);

    uint256[] memory prices = new uint256[](3);
    prices[0] = 29628.25620309 * 1e8;
    prices[1] = 29628.25620309 * 1e8;
    prices[2] = 0.99981427 * 1e8;
    gmBtcPrice = gmBtcUsdPriceAdapter.getPrice(prices);
    prices[0] = 1600.2925 * 1e8;
    prices[1] = 1600.2925 * 1e8;
    prices[2] = 0.99981427 * 1e8;
    gmEthPrice = gmEthUsdPriceAdapter.getPrice(prices);

    assertApproxEqRel(gmBtcPrice, 1.042 * 1e18, MAX_DIFF);
    assertApproxEqRel(gmEthPrice, 0.93 * 1e18, MAX_DIFF);
  }
}
