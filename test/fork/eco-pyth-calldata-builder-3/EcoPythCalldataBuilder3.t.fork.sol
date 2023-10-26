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

  function testCorrectness_build() external view {
    IEcoPythCalldataBuilder3.BuildData[] memory buildData = new IEcoPythCalldataBuilder3.BuildData[](38);
    buildData[0] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ETH",
      priceE8: 1800.99 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[1] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BTC",
      priceE8: 34557.1180495 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[2] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "USDC",
      priceE8: 0.99995001 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[3] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "USDT",
      priceE8: 1.000215 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[4] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "DAI",
      priceE8: 0.99989994 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[5] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AAPL",
      priceE8: 171.18485 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[6] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "JPY",
      priceE8: 150.772 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[7] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XAU",
      priceE8: 1984.63 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[8] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AMZN",
      priceE8: 121.58918 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[9] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "MSFT",
      priceE8: 340.681 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[10] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "TSLA",
      priceE8: 212.56082 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[11] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "EUR",
      priceE8: 1.05338 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[12] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XAG",
      priceE8: 22.934 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[13] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GLP",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[14] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AUD",
      priceE8: 0.62882 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[15] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GBP",
      priceE8: 1.20707 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[16] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ADA",
      priceE8: 0.29079539 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[17] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "MATIC",
      priceE8: 0.64085163 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[18] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SUI",
      priceE8: 0.43960047 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[19] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ARB",
      priceE8: 0.95875444 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[20] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "OP",
      priceE8: 1.4168283 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[21] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "LTC",
      priceE8: 69.16120365 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[22] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "COIN",
      priceE8: 77.79 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[23] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GOOG",
      priceE8: 126.48911 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[24] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BNB",
      priceE8: 223.6 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[25] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SOL",
      priceE8: 32.4529947 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[26] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "QQQ",
      priceE8: 350.59 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[27] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XRP",
      priceE8: 0.55225604 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[28] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "NVDA",
      priceE8: 417.755 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[29] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "LINK",
      priceE8: 11.0394814 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[30] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CHF",
      priceE8: 0.89887 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[31] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "DOGE",
      priceE8: 0.07061008 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[32] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CAD",
      priceE8: 1.38141 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[33] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SGD",
      priceE8: 1.37337 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[34] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "wstETH",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[35] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CNH",
      priceE8: 7.32896 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[36] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "HKD",
      priceE8: 7.82236 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[37] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BCH",
      priceE8: 252.09163826 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    ecoPythCalldataBuilder.build(buildData);
  }

  function testRevert_BadOrder() external {
    IEcoPythCalldataBuilder3.BuildData[] memory buildData = new IEcoPythCalldataBuilder3.BuildData[](38);
    buildData[0] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ETH",
      priceE8: 1800.99 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[1] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ETH",
      priceE8: 34557.1180495 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[2] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "USDC",
      priceE8: 0.99995001 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[3] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "USDT",
      priceE8: 1.000215 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[4] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "DAI",
      priceE8: 0.99989994 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[5] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AAPL",
      priceE8: 171.18485 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[6] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "JPY",
      priceE8: 150.772 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[7] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XAU",
      priceE8: 1984.63 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[8] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AMZN",
      priceE8: 121.58918 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[9] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "MSFT",
      priceE8: 340.681 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[10] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "TSLA",
      priceE8: 212.56082 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[11] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "EUR",
      priceE8: 1.05338 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[12] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XAG",
      priceE8: 22.934 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[13] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GLP",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[14] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AUD",
      priceE8: 0.62882 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[15] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GBP",
      priceE8: 1.20707 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[16] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ADA",
      priceE8: 0.29079539 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[17] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "MATIC",
      priceE8: 0.64085163 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[18] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SUI",
      priceE8: 0.43960047 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[19] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ARB",
      priceE8: 0.95875444 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[20] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "OP",
      priceE8: 1.4168283 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[21] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "LTC",
      priceE8: 69.16120365 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[22] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "COIN",
      priceE8: 77.79 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[23] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GOOG",
      priceE8: 126.48911 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[24] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BNB",
      priceE8: 223.6 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[25] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SOL",
      priceE8: 32.4529947 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[26] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "QQQ",
      priceE8: 350.59 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[27] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XRP",
      priceE8: 0.55225604 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[28] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "NVDA",
      priceE8: 417.755 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[29] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "LINK",
      priceE8: 11.0394814 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[30] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CHF",
      priceE8: 0.89887 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[31] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "DOGE",
      priceE8: 0.07061008 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[32] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CAD",
      priceE8: 1.38141 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[33] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SGD",
      priceE8: 1.37337 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[34] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "wstETH",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[35] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CNH",
      priceE8: 7.32896 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[36] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "HKD",
      priceE8: 7.82236 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[37] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BCH",
      priceE8: 252.09163826 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    vm.expectRevert(
      abi.encodeWithSelector(
        EcoPythCalldataBuilder3.BadOrder.selector,
        1,
        0x4554480000000000000000000000000000000000000000000000000000000000
      )
    );
    ecoPythCalldataBuilder.build(buildData);
  }

  function testRevert_BadLength() external {
    IEcoPythCalldataBuilder3.BuildData[] memory buildData = new IEcoPythCalldataBuilder3.BuildData[](39);
    buildData[0] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ETH",
      priceE8: 1800.99 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[1] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BTC",
      priceE8: 34557.1180495 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[2] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "USDC",
      priceE8: 0.99995001 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[3] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "USDT",
      priceE8: 1.000215 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[4] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "DAI",
      priceE8: 0.99989994 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[5] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AAPL",
      priceE8: 171.18485 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[6] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "JPY",
      priceE8: 150.772 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[7] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XAU",
      priceE8: 1984.63 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[8] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AMZN",
      priceE8: 121.58918 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[9] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "MSFT",
      priceE8: 340.681 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[10] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "TSLA",
      priceE8: 212.56082 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[11] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "EUR",
      priceE8: 1.05338 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[12] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XAG",
      priceE8: 22.934 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[13] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GLP",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[14] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "AUD",
      priceE8: 0.62882 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[15] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GBP",
      priceE8: 1.20707 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[16] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ADA",
      priceE8: 0.29079539 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[17] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "MATIC",
      priceE8: 0.64085163 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[18] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SUI",
      priceE8: 0.43960047 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[19] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ARB",
      priceE8: 0.95875444 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[20] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "OP",
      priceE8: 1.4168283 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[21] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "LTC",
      priceE8: 69.16120365 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[22] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "COIN",
      priceE8: 77.79 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[23] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GOOG",
      priceE8: 126.48911 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[24] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BNB",
      priceE8: 223.6 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[25] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SOL",
      priceE8: 32.4529947 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[26] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "QQQ",
      priceE8: 350.59 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[27] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "XRP",
      priceE8: 0.55225604 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[28] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "NVDA",
      priceE8: 417.755 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[29] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "LINK",
      priceE8: 11.0394814 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[30] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CHF",
      priceE8: 0.89887 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[31] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "DOGE",
      priceE8: 0.07061008 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[32] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CAD",
      priceE8: 1.38141 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[33] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SGD",
      priceE8: 1.37337 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[34] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "wstETH",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[35] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CNH",
      priceE8: 7.32896 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[36] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "HKD",
      priceE8: 7.82236 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[37] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BCH",
      priceE8: 252.09163826 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    buildData[38] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BCH",
      priceE8: 252.09163826 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    vm.expectRevert("BAD_LENGTH");
    ecoPythCalldataBuilder.build(buildData);
  }
}
