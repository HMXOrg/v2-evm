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
    // vm.createSelectFork(vm.envString("BLAST_SEPOLIA_RPC"), 6798187);
    vm.createSelectFork(vm.envString("BLAST_SEPOLIA_RPC"));

    vm.startPrank(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a);

    // bytes32[] memory priceData = new bytes32[](6);
    // priceData[0] = 0x013eb001b275ffffff000000ffffff00c58b012eb60002fd0083fffff0160000;
    // priceData[1] = 0x000993ffdeebffed91ffffa6fffd8f001c1900aaa200fa3f00c3b4ffe3b10000;
    // priceData[2] = 0x006a8efffba9ffb41b000c67000bb0004d7d00504b00ee21ff6991005b840000;
    // priceData[3] = 0x00b459002c890020220099650051ae00873a00850f00490effe19b004f2f0000;
    // priceData[4] = 0xff544eff69e2005999000ceb013eb600002c000065ffda88003fb6ffe4330000;
    // priceData[5] = 0xfff2180000000000000000000000000000000000000000000000000000000000;

    // bytes32[] memory publishTimeData = new bytes32[](6);
    // publishTimeData[0] = 0x0000030000030000030000030000000000000000000000000000000000000000;
    // publishTimeData[1] = 0x0000000000030000030000030000030000030000030000030000030000030000;
    // publishTimeData[2] = 0x0000030000000000030000000000000000000000000000030000030000000000;
    // publishTimeData[3] = 0x0000040000030000030000030000030000030000030000030000030000030000;
    // publishTimeData[4] = 0x0000030000000000030000000000040000040000030000030000000000000000;
    // publishTimeData[5] = 0x0000030000000000000000000000000000000000000000000000000000000000;

    // address[] memory _accounts = new address[](1);
    // _accounts[0] = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a;

    // uint8[] memory _subAccountIds = new uint8[](1);
    // _subAccountIds[0] = 1;

    // uint256[] memory _orderIndexes = new uint256[](1);
    // _orderIndexes[0] = 50;

    // ILiquidityHandler(payable(0xFc99D238c7A20895ba3756Ee04FD8BfD442c18fD)).executeOrder(
    //   265,
    //   payable(0x0578C797798Ae89b688Cd5676348344d7d0EC35E),
    //   priceData,
    //   publishTimeData,
    //   1718283050,
    //   0x259c68b8d20b4292c8465ea4c94c75481334bc86e42803313f8545a7f78e6182
    // );

    IBotHandler(0x34eFfFEdbD326796256B4C253dC3F8F1dfe23D63).removeTokenFromHlpLiquidity(
      0xfAE1131D79E9B13CA11c3Fb3D7b588D8Fa44401c,
      18628136730
    );

    vm.stopPrank();
  }
}
