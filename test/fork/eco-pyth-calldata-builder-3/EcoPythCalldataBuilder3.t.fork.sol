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
import { UnsafeEcoPythCalldataBuilder3 } from "@hmx/oracles/UnsafeEcoPythCalldataBuilder3.sol";
import { CIXPriceAdapter } from "@hmx/oracles/CIXPriceAdapter.sol";

contract EcoPythCalldataBuilder3_ForkTest is ForkEnv, Cheats {
  CIXPriceAdapter internal cix1PriceAdapter;
  CalcPriceLens internal calcPriceLens;
  EcoPythCalldataBuilder3 internal ecoPythCalldataBuilder;
  UnsafeEcoPythCalldataBuilder3 internal unsafeEcoPythCalldataBuilder;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 138960612);

    // glpPriceAdapter = new CIXPriceAdapter(ForkEnv.sglp, ForkEnv.glpManager);

    cix1PriceAdapter = new CIXPriceAdapter();
    _setupCIX1PriceAdapter();

    calcPriceLens = new CalcPriceLens();
    _setupCalcPriceLens();

    ecoPythCalldataBuilder = new EcoPythCalldataBuilder3(
      ForkEnv.ecoPyth2,
      ForkEnv.onChainPriceLens,
      calcPriceLens,
      false
    );

    unsafeEcoPythCalldataBuilder = new UnsafeEcoPythCalldataBuilder3(
      ForkEnv.ecoPyth2,
      ForkEnv.onChainPriceLens,
      calcPriceLens,
      false
    );

    // _addSek();
  }

  function _addSek() internal {
    vm.startPrank(ForkEnv.multiSig);
    ForkEnv.ecoPyth2.insertAssetId("SEK");
    vm.stopPrank();

    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();

    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    IEcoPythCalldataBuilder3.BuildData[] memory data = new IEcoPythCalldataBuilder3.BuildData[](len + 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }

    data[len] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "SEK",
      priceE8: 11.00e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });

    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,

    ) = unsafeEcoPythCalldataBuilder.build(data);

    vm.startPrank(address(ForkEnv.botHandler));
    ForkEnv.ecoPyth2.updatePriceFeeds(
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("pyth")
    );
    vm.stopPrank();
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
  }

  function _setupCalcPriceLens() internal {
    bytes32[] memory priceIds = new bytes32[](1);
    priceIds[0] = "CIX1";
    ICalcPriceAdapter[] memory priceAdapters = new ICalcPriceAdapter[](1);
    priceAdapters[0] = cix1PriceAdapter;
    calcPriceLens.setPriceAdapters(priceIds, priceAdapters);
  }

  function testCorrectness_OnChainPriceLens_getPrice() external {
    uint256 wstEthUsdPrice = onChainPriceLens.getPrice("wstETH");
    assertEq(wstEthUsdPrice, 1849.608961014197395889 ether);

    uint256 glpPrice = onChainPriceLens.getPrice("GLP");
    assertEq(glpPrice, 0.966239558995737274 ether);
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

  function testCorrectness_EcoPythCalldataBuilder3_build() external {
    IEcoPythCalldataBuilder3.BuildData[] memory _data = new IEcoPythCalldataBuilder3.BuildData[](11);
    _data[0] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "ETH",
      priceE8: 1594e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[1] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GLP",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[2] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "BTC",
      priceE8: 25794.75 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[3] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "wstETH",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[4] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CIX1",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[5] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "EUR",
      priceE8: 1.05048e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[6] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CHF",
      priceE8: 0.92e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[7] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CAD",
      priceE8: 1.349e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[8] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "JPY",
      priceE8: 180.00e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 100000
    });
    _data[9] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "GBP",
      priceE8: 1.2142e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[10] = IEcoPythCalldataBuilder3.BuildData({
      assetId: "CNH",
      priceE8: 11.06e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 100000
    });

    ecoPythCalldataBuilder.build(_data);
    // unsafeEcoPythCalldataBuilder.build(_data);
  }
}
