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
import { EcoPyth3 } from "@hmx/oracles/EcoPyth3.sol";
import { EcoPythCalldataBuilder4 } from "@hmx/oracles/EcoPythCalldataBuilder4.sol";
import { UnsafeEcoPythCalldataBuilder4 } from "@hmx/oracles/UnsafeEcoPythCalldataBuilder4.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

contract EcoPythCalldataBuilder4_ForkTest is ForkEnv, Cheats {
  uint256 constant MAX_DIFF = 0.001 ether; // 0.1 %

  EcoPyth3 internal ecoPyth;
  EcoPythCalldataBuilder4 internal ecoPythCalldataBuilder;
  UnsafeEcoPythCalldataBuilder4 internal unsafeEcoPythCalldataBuilder;

  function setUp() external {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 172949546);

    ecoPyth = new EcoPyth3();
    bytes32[] memory _assetIds = ForkEnv.ecoPyth2.getAssetIds();
    for (uint i = 3; i < _assetIds.length; i++) {
      ecoPyth.insertAssetId(_assetIds[i]);
    }
    ecoPyth.setUpdater(address(this), true);

    ecoPythCalldataBuilder = new EcoPythCalldataBuilder4(
      ecoPyth,
      ForkEnv.onChainPriceLens,
      ForkEnv.calcPriceLens,
      false
    );

    unsafeEcoPythCalldataBuilder = new UnsafeEcoPythCalldataBuilder4(
      ecoPyth,
      ForkEnv.onChainPriceLens,
      ForkEnv.calcPriceLens,
      false
    );

    // 1st feed
    // Prepare build data
    IEcoPythCalldataBuilder3.BuildData[] memory _data = _getCurrentBuildData();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,

    ) = unsafeEcoPythCalldataBuilder.build(_data);
    ecoPyth.updatePriceFeeds(_priceUpdateCalldata, _publishTimeUpdateCalldata, _minPublishTime, keccak256("pyth"));
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

  function testCorrectness_EcoPythCalldataBuilder4_Build() external {
    // Prepare build data
    IEcoPythCalldataBuilder3.BuildData[] memory _data = _getCurrentBuildData();
    _overwritePriceByAssetId("BTC", _data, 40_400e8, 15_000);

    // Build
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,

    ) = ecoPythCalldataBuilder.build(_data);

    // Feed
    ecoPyth.updatePriceFeeds(_priceUpdateCalldata, _publishTimeUpdateCalldata, _minPublishTime, keccak256("pyth"));

    // Assertions
    // Assert GLP
    {
      PythStructs.Price memory _p = ecoPyth.getPriceUnsafe("GLP");
      assertEq(_p.price, 1.16136091e8);
    }
    // Assert wstETH
    {
      PythStructs.Price memory _p = ecoPyth.getPriceUnsafe("wstETH");
      assertEq(_p.price, 2790.57600370e8);
    }
    // Randomly assert the common assets, to ensure the data sequence
    {
      PythStructs.Price memory _p;
      _p = ecoPyth.getPriceUnsafe("BTC");
      assertEq(_p.price, 40_400e8);
      _p = ecoPyth.getPriceUnsafe("ETH");
      assertEq(_p.price, 2418.51854683e8);
      _p = ecoPyth.getPriceUnsafe("JPY");
      assertEq(_p.price, 148.02040511e8);
      _p = ecoPyth.getPriceUnsafe("XAG");
      assertEq(_p.price, 22.13909688e8);
      _p = ecoPyth.getPriceUnsafe("NVDA");
      assertEq(_p.price, 594.83293897e8);
      _p = ecoPyth.getPriceUnsafe("BCH");
      assertEq(_p.price, 234.56368250e8);
    }
  }

  function testCorrectness_UnsafeEcoPythCalldataBuilder4_ShouldBuildTheSameResultAsSafeOne() external {
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

  function testRevert_BadOrder() external {
    IEcoPythCalldataBuilder3.BuildData[] memory buildData = _getCurrentBuildData();
    buildData[1].assetId = "WETH";

    vm.expectRevert(
      abi.encodeWithSelector(
        EcoPythCalldataBuilder4.BadOrder.selector,
        1,
        0x5745544800000000000000000000000000000000000000000000000000000000
      )
    );
    ecoPythCalldataBuilder.build(buildData);
  }

  function testRevert_BadLength() external {
    IEcoPythCalldataBuilder3.BuildData[] memory buildData = new IEcoPythCalldataBuilder3.BuildData[](60);
    for (uint i = 0; i < buildData.length; i++) {
      buildData[i] = IEcoPythCalldataBuilder3.BuildData({
        assetId: "ETH",
        priceE8: 1800.99 * 1e8,
        publishTime: uint160(block.timestamp),
        maxDiffBps: 15000
      });
    }
    vm.expectRevert("BAD_LENGTH");
    ecoPythCalldataBuilder.build(buildData);
  }
}
