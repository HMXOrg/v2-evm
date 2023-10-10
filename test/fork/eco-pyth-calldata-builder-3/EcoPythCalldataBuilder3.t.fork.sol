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

  function _setupCalcPriceLens() internal {
    bytes32[] memory priceIds = new bytes32[](1);
    priceIds[0] = "CIX1";
    ICalcPriceAdapter[] memory priceAdapters = new ICalcPriceAdapter[](1);
    priceAdapters[0] = cix1PriceAdapter;
    calcPriceLens.setPriceAdapters(priceIds, priceAdapters);
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
      assertEq(_p.price, 0.96618661e8);
    }

    // Assert wstETH
    {
      PythStructs.Price memory _p = ForkEnv.ecoPyth2.getPriceUnsafe("wstETH");
      assertEq(_p.price, 1849.59850477e8);
    }

    // Randomly assert the common assets, to ensure the data sequence
    {
      PythStructs.Price memory _p;
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("BTC");
      assertEq(_p.price, 27852.78594028e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("ETH");
      assertEq(_p.price, 1621.21388544e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("JPY");
      assertEq(_p.price, 149.38840760e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("XAG");
      assertEq(_p.price, 21.72679030e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("NVDA");
      assertEq(_p.price, 457.50770011e8);
      _p = ForkEnv.ecoPyth2.getPriceUnsafe("BCH");
      assertEq(_p.price, 226.85902471e8);
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
}
