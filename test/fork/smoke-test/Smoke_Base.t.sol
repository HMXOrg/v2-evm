// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

import { ILiquidationReader } from "@hmx/readers/interfaces/ILiquidationReader.sol";
import { ILiquidationService } from "@hmx/services/interfaces/ILiquidationService.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";

import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";

import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

// import { PositionTester } from "../../testers/PositionTester.sol";
// import { PositionTester02 } from "../../testers/PositionTester02.sol";
// import { MarketTester } from "../../testers/MarketTester.sol";

contract Smoke_Base is Test {
  ITradeHelper internal tradeHelper;

  ITradeService internal tradeService;
  ILiquidationService internal liquidationService;
  ILiquidationReader internal liquidationReader;

  // PositionTester internal positionTester;
  // PositionTester02 internal positionTester02;
  // MarketTester internal globalMarketTester;

  IEcoPyth internal ecoPyth;
  // storages
  IConfigStorage internal configStorage;
  IPerpStorage internal perpStorage;
  IVaultStorage internal vaultStorage;

  ICalculator internal calculator;

  IBotHandler internal botHandler;

  address internal constant OWNER = 0x6409ba830719cd0fE27ccB3051DF1b399C90df4a;
  address internal constant POS_MANAGER = 0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E; // set market status;
  address internal ALICE;
  address internal BOB;

  function setUp() public virtual {
    ALICE = makeAddr("Alice");
    BOB = makeAddr("BOB");

    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 130344667);

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

    calculator = ICalculator(0x0FdE910552977041Dc8c7ef652b5a07B40B9e006);

    // positionTester = new PositionTester(perpStorage, vaultStorage, mockOracle);
    // positionTester02 = new PositionTester02(perpStorage);
    // globalMarketTester = new MarketTester(perpStorage);

    // deploy services
    address[] memory _updaters = new address[](2);
    _updaters[0] = address(botHandler);
    _updaters[1] = address(this);
    bool[] memory _actives = new bool[](2);
    _actives[0] = true;
    _actives[1] = true;

    address[] memory _positionManagers = new address[](1);
    _positionManagers[0] = address(this);

    vm.stopPrank();
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
}
