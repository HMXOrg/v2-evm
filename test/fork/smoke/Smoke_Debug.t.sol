// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Deployer, IEcoPythCalldataBuilder3, ILimitTradeHandler, ILiquidityHandler, IIntentHandler, IGasService, ICrossMarginHandler, IBotHandler, ITradeOrderHelper, ITradeService, ILiquidityService, ILiquidationService, ICrossMarginService, ITradeHelper, ICalculator, IVaultStorage, IPerpStorage, IConfigStorage, IOracleMiddleware, IPythAdapter, IEcoPythCalldataBuilder, IEcoPyth, IIntentHandler, IIntentHandler } from "@hmx-test/libs/Deployer.sol";
import { OnChainPriceLens } from "@hmx/oracles/OnChainPriceLens.sol";
import { CalcPriceLens } from "@hmx/oracles/CalcPriceLens.sol";
import { UnsafeEcoPythCalldataBuilder3 } from "@hmx/oracles/UnsafeEcoPythCalldataBuilder3.sol";
import { ForkEnv, OrderbookOracle, AdaptiveFeeCalculator } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";
import { IntentBuilder } from "@hmx-test/libs/IntentBuilder.sol";
import { console } from "forge-std/console.sol";

contract Smoke_Debug is ForkEnv {
  int64[] priceE8s;

  function setUp() external {
    priceE8s = new int64[](5);
    priceE8s[0] = 2338.39057711 * 1e8;
    priceE8s[1] = 42999.728223 * 1e8;
    priceE8s[2] = 1.00015007 * 1e8;
    priceE8s[3] = 0.99948283 * 1e8;
    priceE8s[4] = 80.1 * 1e8;
  }

  function test() external {
    vm.createSelectFork(vm.envString("BLAST_SEPOLIA_RPC"), 4534854);

    vm.startPrank(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a);

    bytes32[] memory priceData = new bytes32[](6);
    priceData[0] = 0x013ad701b102ffffff000001fffffe00c4f0012f76000281008200ffeece0000;
    priceData[1] = 0x000858ffe54dfff369000cfd0007680023a900ad8500f99000c382ffe7860000;
    priceData[2] = 0x006bb5fffc64ffb852000c5f000c0b004d6500506800f349ff75fe005d580000;
    priceData[3] = 0x00b4c70034990028c6009867005f6d008db30082e0004d41ffeda200553e0000;
    priceData[4] = 0xff38c2ff72a5006a04001a22013adb00001a000b1ffff0a3004517ffedbb0000;
    priceData[5] = 0x00024b0000000000000000000000000000000000000000000000000000000000;

    bytes32[] memory publishTimeData = new bytes32[](6);
    publishTimeData[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
    publishTimeData[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
    publishTimeData[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
    publishTimeData[3] = 0x0000030000000000000000000000000000000000000000000000000000000000;
    publishTimeData[4] = 0x0000000000000000000000000000030000030000000000000000000000000000;
    publishTimeData[5] = 0x0000000000000000000000000000000000000000000000000000000000000000;

    address[] memory _accounts = new address[](1);
    _accounts[0] = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a;

    uint8[] memory _subAccountIds = new uint8[](1);
    _subAccountIds[0] = 1;

    uint256[] memory _orderIndexes = new uint256[](1);
    _orderIndexes[0] = 50;

    ILimitTradeHandler(payable(0xF1b49fd29240a6f91988f18322e7851cB9a88BEe)).executeOrders(
      _accounts,
      _subAccountIds,
      _orderIndexes,
      payable(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a),
      priceData,
      publishTimeData,
      1713756389,
      0xe14423cae1bfe5774ec5916d5a3777f22da1659180f0af60fd9ab7e05bbd1916,
      true
    );

    vm.stopPrank();
  }
}
