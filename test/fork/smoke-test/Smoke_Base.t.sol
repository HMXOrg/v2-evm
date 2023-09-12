// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";

import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { ILiquidationReader } from "@hmx/readers/interfaces/ILiquidationReader.sol";
import { ILiquidationService } from "@hmx/services/interfaces/ILiquidationService.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";

import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";

import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Smoke_Base is Test {
  ITradeHelper internal tradeHelper;

  ITradeService internal tradeService;
  ILiquidationService internal liquidationService;
  ILiquidationReader internal liquidationReader;
  IEcoPyth internal ecoPyth;

  // storages
  IConfigStorage internal configStorage;
  IPerpStorage internal perpStorage;
  IVaultStorage internal vaultStorage;

  ICalculator internal calculator;

  IBotHandler internal botHandler;

  IEcoPythCalldataBuilder internal ecoPythBuilder;

  ProxyAdmin internal proxyAdmin;

  address internal constant OWNER = 0x6409ba830719cd0fE27ccB3051DF1b399C90df4a;
  address internal constant POS_MANAGER = 0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E; // set market status;
  address internal ALICE;
  address internal BOB;

  function setUp() public virtual {
    ALICE = makeAddr("Alice");
    BOB = makeAddr("BOB");

    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 130344667);

    // -- LOAD FORK -- //
    vm.startPrank(OWNER);
    ecoPyth = IEcoPyth(0x8dc6A40465128B20DC712C6B765a5171EF30bB7B);
    tradeHelper = ITradeHelper(0x963Cbe4cFcDC58795869be74b80A328b022DE00C);
    tradeService = ITradeService(0xcf533D0eEFB072D1BB68e201EAFc5368764daA0E);
    botHandler = IBotHandler(0xD4CcbDEbE59E84546fd3c4B91fEA86753Aa3B671);
    liquidationService = ILiquidationService(0x34E89DEd96340A177856fD822366AfC584438750);
    liquidationReader = ILiquidationReader(0x9f13335e769208a2545047aCb0ea386Cce7F5f8F);

    configStorage = IConfigStorage(0xF4F7123fFe42c4C90A4bCDD2317D397E0B7d7cc0);
    perpStorage = IPerpStorage(0x97e94BdA44a2Df784Ab6535aaE2D62EFC6D2e303);
    vaultStorage = IVaultStorage(0x56CC5A9c0788e674f17F7555dC8D3e2F1C0313C0);

    proxyAdmin = ProxyAdmin(0x2E7983f9A1D08c57989eEA20adC9242321dA6589);
    ecoPythBuilder = IEcoPythCalldataBuilder(0x4c3eC30d33c6CfC8B0806Bf049eA907FE4a0AB4F); // UnsafeEcoPythCalldataBuilder

    // -- LOAD FORK -- //
    vm.stopPrank();

    // -- UPGRADE -- //
    vm.startPrank(proxyAdmin.owner());
    Calculator newCalculator = new Calculator();
    proxyAdmin.upgrade(
      TransparentUpgradeableProxy(payable(0x0FdE910552977041Dc8c7ef652b5a07B40B9e006)),
      address(newCalculator)
    );

    // -- LOAD UPGRADE -- //
    vm.stopPrank();

    calculator = ICalculator(0x0FdE910552977041Dc8c7ef652b5a07B40B9e006);
  }

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  function _getPositionId(address _account, uint8 _subAccountId, uint256 _marketIndex) internal pure returns (bytes32) {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  function _setTickPriceZero()
    internal
    view
    returns (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData)
  {
    int24[] memory tickPrices = new int24[](34);
    uint24[] memory publishTimeDiffs = new uint24[](34);
    for (uint i = 0; i < 34; i++) {
      tickPrices[i] = 0;
      publishTimeDiffs[i] = 0;
    }

    priceUpdateData = ecoPyth.buildPriceUpdateData(tickPrices);
    publishTimeUpdateData = ecoPyth.buildPublishTimeUpdateData(publishTimeDiffs);
  }

  function _setPriceData()
    internal
    view
    returns (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts)
  {
    bytes32[] memory pythRes = ecoPyth.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34
    assetIds = new bytes32[](len - 1);
    prices = new uint64[](len - 1);
    shouldInverts = new bool[](len - 1);

    for (uint i = 1; i < len; i++) {
      assetIds[i - 1] = pythRes[i];
      prices[i - 1] = 1 * 1e8;
      if (i == 4) {
        shouldInverts[i - 1] = true; // JPY
      } else {
        shouldInverts[i - 1] = false;
      }
    }
  }

  function _setTickPriceMAX()
    internal
    view
    returns (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData)
  {
    int24[] memory tickPrices = new int24[](34);
    uint24[] memory publishTimeDiffs = new uint24[](34);
    for (uint i = 0; i < 34; i++) {
      tickPrices[i] = 10000;
      publishTimeDiffs[i] = 0;
    }

    priceUpdateData = ecoPyth.buildPriceUpdateData(tickPrices);
    publishTimeUpdateData = ecoPyth.buildPublishTimeUpdateData(publishTimeDiffs);
  }

  function _buildDataForPrice() internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ecoPyth.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ecoPyth.getPriceUnsafe(pythRes[i]);
      console.logInt(_ecoPythPrice.price);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }
}
