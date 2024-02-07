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
import { IGmxV2Reader } from "@hmx/interfaces/gmx-v2/IGmxV2Reader.sol";
import { CIXPriceAdapter } from "@hmx/oracles/CIXPriceAdapter.sol";
import { UnsafeEcoPythCalldataBuilder3 } from "@hmx/oracles/UnsafeEcoPythCalldataBuilder3.sol";

contract EcoPythCalldataBuilder3_ForkTest is ForkEnv, Cheats {
  uint256 constant MAX_DIFF = 0.001 ether; // 0.1 %

  CIXPriceAdapter internal cix1PriceAdapter;
  UnsafeEcoPythCalldataBuilder3 internal unsafeEcoPythCalldataBuilder;
  CalcPriceLens internal calcPriceLens;
  EcoPythCalldataBuilder3 internal ecoPythCalldataBuilder;
  GmPriceAdapter internal gmBtcUsdPriceAdapter;
  GmPriceAdapter internal gmEthUsdPriceAdapter;

  function setUp() external {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 142248340);

    cix1PriceAdapter = new CIXPriceAdapter();
    _setupCIX1PriceAdapter();

    calcPriceLens = new CalcPriceLens();
    _setupGmPriceAdapters();
    _setupCalcPriceLens();

    ecoPythCalldataBuilder = new EcoPythCalldataBuilder3(ForkEnv.ecoPyth2, ForkEnv.onChainPriceLens, calcPriceLens);

    unsafeEcoPythCalldataBuilder = new UnsafeEcoPythCalldataBuilder3(
      ForkEnv.ecoPyth2,
      ForkEnv.onChainPriceLens,
      calcPriceLens
    );
  }

  function _setupCIX1PriceAdapter() internal {
    /* 
      EURUSD	55.00%
      USDJPY	15.00%
      GBPUSD	12.50%
      USDCAD	10.00%
      USDCNH	4.00%  // Use CNH instead of SEK
      USDCHF	3.50%

      C = 43.92050844
    */

    bytes32[] memory _assetIds = new bytes32[](6);
    _assetIds[0] = "EUR";
    _assetIds[1] = "JPY";
    _assetIds[2] = "GBP";
    _assetIds[3] = "CAD";
    _assetIds[4] = "CNH";
    _assetIds[5] = "CHF";

    uint256[] memory _weightsE8 = new uint256[](6);
    _weightsE8[0] = 0.55e8;
    _weightsE8[1] = 0.15e8;
    _weightsE8[2] = 0.125e8;
    _weightsE8[3] = 0.10e8;
    _weightsE8[4] = 0.04e8;
    _weightsE8[5] = 0.035e8;

    bool[] memory _usdQuoteds = new bool[](6);
    _usdQuoteds[0] = true;
    _usdQuoteds[1] = false;
    _usdQuoteds[2] = true;
    _usdQuoteds[3] = false;
    _usdQuoteds[4] = false;
    _usdQuoteds[5] = false;

    uint256 _c = 43.92050844e8;

    cix1PriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);

    vm.startPrank(ForkEnv.multiSig);
    ForkEnv.ecoPyth2.insertAssetId("CIX1");
    vm.stopPrank();
  }

  function testCorrectness_CalcPriceLens_getPrice() external {
    IEcoPythCalldataBuilder3.BuildData[] memory _buildDatas = new IEcoPythCalldataBuilder3.BuildData[](10);
    _buildDatas[0].assetId = "EUR";
    _buildDatas[0].priceE8 = 1.05048e8;

    _buildDatas[1].assetId = "UNKNOWN1";
    _buildDatas[1].priceE8 = 1.1e8;

    _buildDatas[2].assetId = "UNKNOWN2";
    _buildDatas[2].priceE8 = 2.2e8;

    _buildDatas[3].assetId = "CHF";
    _buildDatas[3].priceE8 = 0.92e8;

    _buildDatas[4].assetId = "CAD";
    _buildDatas[4].priceE8 = 1.349e8;

    _buildDatas[5].assetId = "UNKNOWN3";
    _buildDatas[5].priceE8 = 3.3e8;

    _buildDatas[6].assetId = "JPY";
    _buildDatas[6].priceE8 = 149.39e8;

    _buildDatas[7].assetId = "UNKNOWN4";
    _buildDatas[7].priceE8 = 4.4e8;

    _buildDatas[8].assetId = "GBP";
    _buildDatas[8].priceE8 = 1.2142e8;

    _buildDatas[9].assetId = "CNH";
    _buildDatas[9].priceE8 = 11.06e8;

    uint256 p = calcPriceLens.getPrice("CIX1", _buildDatas);
    assertApproxEqRel(p, 100e18, 0.00000001e18, "Price E18 should be 100 USD");
  }

  function _getCurrentBuildData() internal view returns (IEcoPythCalldataBuilder3.BuildData[] memory data) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();
    uint256 len = pythRes.length;
    data = new IEcoPythCalldataBuilder3.BuildData[](len - 1);
    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _overwritePriceByAssetId(
    bytes32 _assetId,
    IEcoPythCalldataBuilder3.BuildData[] memory _data,
    int64 _newPriceE8,
    uint32 _newMaxDiffBps
  ) internal pure returns (IEcoPythCalldataBuilder3.BuildData[] memory) {
    uint256 len = _data.length;

    for (uint i = 1; i < len; i++) {
      if (_assetId == _data[i].assetId) {
        _data[i].priceE8 = _newPriceE8;
        _data[i].maxDiffBps = _newMaxDiffBps;
        return _data;
      }
    }

    require(false, "Assset not found");
    return _data;
  }

  function testCorrectness_EcoPythCalldataBuilder3_build() external {
    // Prepare build data
    IEcoPythCalldataBuilder3.BuildData[] memory _data = _getCurrentBuildData();
    _overwritePriceByAssetId("EUR", _data, 1.05048e8, 15_000);
    _overwritePriceByAssetId("CHF", _data, 0.92e8, 15_000);
    _overwritePriceByAssetId("CAD", _data, 1.349e8, 15_000);
    _overwritePriceByAssetId("JPY", _data, 149.39e8, 15_000);
    _overwritePriceByAssetId("GBP", _data, 1.2142e8, 15_000);
    _overwritePriceByAssetId("CNH", _data, 11.06e8, 100_000); // Use SEK price here

    // Build
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,

    ) = ecoPythCalldataBuilder.build(_data);
    vm.startPrank(address(ForkEnv.botHandler));

    // Feed
    ForkEnv.ecoPyth2.updatePriceFeeds(
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("pyth")
    );
    vm.stopPrank();

    // Assertions

    // Assert CIX
    {
      PythStructs.Price memory _p = ForkEnv.ecoPyth2.getPriceUnsafe("CIX1");
      assertApproxEqRel(_p.price, 100e8, 0.000001e18, "CIX1 price should be 100 USD"); // 0.000001% error
    }

    // Assert GLP
    {
      PythStructs.Price memory _p = ForkEnv.ecoPyth2.getPriceUnsafe("GLP");
      assertEq(_p.price, 0.97687279e8);
    }

    // Assert wstETH
    {
      PythStructs.Price memory _p = ForkEnv.ecoPyth2.getPriceUnsafe("wstETH");
      assertEq(_p.price, 1828.26818365e8);
    }

    // Randomly assert the common assets, to ensure the data sequence
    {
      PythStructs.Price memory _p;
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("BTC");
      assertEq(_p.price, 29619.41090842e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("ETH");
      assertEq(_p.price, 1599.95553880e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("JPY");
      assertEq(_p.price, 149.38840760e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("XAG");
      assertEq(_p.price, 23.23692749e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("NVDA");
      assertEq(_p.price, 420.90109828e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("BCH");
      assertEq(_p.price, 241.27218831e8);
    }
  }

  function testCorrectness_UnsafeEcoPythCalldataBuilder3_shouldBuildTheSameResultAsSafeOne() external {
    IEcoPythCalldataBuilder3.BuildData[] memory _data = _getCurrentBuildData();
    _overwritePriceByAssetId("EUR", _data, 1.05048e8, 15_000);
    _overwritePriceByAssetId("CHF", _data, 0.92e8, 15_000);
    _overwritePriceByAssetId("CAD", _data, 1.349e8, 15_000);
    _overwritePriceByAssetId("JPY", _data, 149.39e8, 15_000);
    _overwritePriceByAssetId("GBP", _data, 1.2142e8, 15_000);
    _overwritePriceByAssetId("CNH", _data, 11.06e8, 100_000); // Use SEK price here

    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,

    ) = ecoPythCalldataBuilder.build(_data);

    (
      uint256 _unsafeMinPublishTime,
      bytes32[] memory _unsafePriceUpdateCalldata,
      bytes32[] memory _unsafePublishTimeUpdateCalldata,

    ) = unsafeEcoPythCalldataBuilder.build(_data);

    assertEq(_minPublishTime, _unsafeMinPublishTime);

    for (uint i = 0; i < _priceUpdateCalldata.length; i++) {
      assertEq(_priceUpdateCalldata[i], _unsafePriceUpdateCalldata[i]);
    }

    for (uint i = 0; i < _publishTimeUpdateCalldata.length; i++) {
      assertEq(_publishTimeUpdateCalldata[i], _unsafePublishTimeUpdateCalldata[i]);
    }
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
    bytes32[] memory priceIds = new bytes32[](3);
    priceIds[0] = "GM-BTCUSD";
    priceIds[1] = "GM-ETHUSD";
    priceIds[2] = "CIX1";
    ICalcPriceAdapter[] memory priceAdapters = new ICalcPriceAdapter[](3);
    priceAdapters[0] = gmBtcUsdPriceAdapter;
    priceAdapters[1] = gmEthUsdPriceAdapter;
    priceAdapters[2] = cix1PriceAdapter;
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
    IEcoPythCalldataBuilder3.BuildData[] memory buildData = new IEcoPythCalldataBuilder3.BuildData[](40);
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
    buildData[39] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BCH",
      priceE8: 252.09163826 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    vm.expectRevert("BAD_LENGTH");
    ecoPythCalldataBuilder.build(buildData);
  }
}
