// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Deployer, IEcoPythCalldataBuilder3, ILiquidityHandler, IIntentHandler, IGasService, ICrossMarginHandler, IBotHandler, ITradeOrderHelper, ITradeService, ILiquidityService, ILiquidationService, ICrossMarginService, ITradeHelper, ICalculator, IVaultStorage, IPerpStorage, IConfigStorage, IOracleMiddleware, IPythAdapter, IEcoPythCalldataBuilder, IEcoPyth, IIntentHandler, IIntentHandler } from "@hmx-test/libs/Deployer.sol";
import { OnChainPriceLens } from "@hmx/oracles/OnChainPriceLens.sol";
import { CalcPriceLens } from "@hmx/oracles/CalcPriceLens.sol";
import { UnsafeEcoPythCalldataBuilder3 } from "@hmx/oracles/UnsafeEcoPythCalldataBuilder3.sol";
import { ForkEnv, OrderbookOracle, AdaptiveFeeCalculator } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";
import { IntentBuilder } from "@hmx-test/libs/IntentBuilder.sol";
import { console } from "forge-std/console.sol";
import { OrderReader } from "@hmx/readers/OrderReader.sol";

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
    vm.createSelectFork(vm.envString("BLAST_SEPOLIA_RPC"));

    OrderReader orderReader = OrderReader(0xf64DCCfedB413014B2B53b5330DEd402c3CB32A2);
    uint64[] memory _prices = new uint64[](46);
    _prices[0] = 352071104199;
    _prices[1] = 6898488146585;
    _prices[2] = 15186400000;
    _prices[3] = 234715000000;
    _prices[4] = 108614000;
    _prices[5] = 2807937000;
    _prices[6] = 66237000;
    _prices[7] = 126966000;
    _prices[8] = 57799999;
    _prices[9] = 88217694;
    _prices[10] = 153964014;
    _prices[11] = 146651637;
    _prices[12] = 300549999;
    _prices[13] = 9607290667;
    _prices[14] = 58865005000;
    _prices[15] = 17044353500;
    _prices[16] = 61030789;
    _prices[17] = 1737850000;
    _prices[18] = 90364000;
    _prices[19] = 18787450;
    _prices[20] = 135650000;
    _prices[21] = 134450000;
    _prices[22] = 724158000;
    _prices[23] = 783250000;
    _prices[24] = 61287484642;
    _prices[25] = 3714654;
    _prices[26] = 10037716236;
    _prices[27] = 375347977;
    _prices[28] = 312280827;
    _prices[29] = 6974642597;
    _prices[30] = 1128617923;
    _prices[31] = 4702349999;
    _prices[32] = 3265216855;
    _prices[33] = 842450000;
    _prices[34] = 66875005;
    _prices[35] = 1073050040;
    _prices[36] = 693490;
    _prices[37] = 2747660;
    _prices[38] = 1054464000;
    _prices[39] = 1572693123;
    _prices[40] = 271067636;
    _prices[41] = 183777669;
    _prices[42] = 75131630;
    _prices[43] = 623162149;
    _prices[44] = 83587927;
    _prices[45] = 139548830;

    bool[] memory _shouldInverts = new bool[](46);
    orderReader.getExecutableOrders(900, 0, _prices, _shouldInverts);
  }
}
