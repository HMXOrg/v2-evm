// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

// to-upgrade contract
import { HLP } from "@hmx/contracts/HLP.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";

import { TradeService } from "@hmx/services/TradeService.sol";
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";

import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";
import { OrderReader } from "@hmx/readers/OrderReader.sol";

// Storage
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { UncheckedEcoPythCalldataBuilder } from "@hmx/oracles/UncheckedEcoPythCalldataBuilder.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract Smoke_Base is ForkEnv {
  uint256 internal constant BPS = 10_000;

  UncheckedEcoPythCalldataBuilder uncheckedBuilder;
  OrderReader newOrderReader;

  function setUp() public virtual {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 132436832);

    uncheckedBuilder = new UncheckedEcoPythCalldataBuilder(ForkEnv.ecoPyth2, ForkEnv.glpManager, ForkEnv.sglp);

    // -- UPGRADE -- //
    vm.startPrank(ForkEnv.proxyAdmin.owner());
    Deployer.upgrade("Calculator", address(ForkEnv.proxyAdmin), address(ForkEnv.calculator));
    Deployer.upgrade("HLP", address(ForkEnv.proxyAdmin), address(ForkEnv.hlp));
    Deployer.upgrade("BotHandler", address(ForkEnv.proxyAdmin), address(ForkEnv.botHandler));
    Deployer.upgrade("LimitTradeHandler", address(ForkEnv.proxyAdmin), address(ForkEnv.limitTradeHandler));
    Deployer.upgrade("TradeService", address(ForkEnv.proxyAdmin), address(ForkEnv.tradeService));
    Deployer.upgrade("CrossMarginService", address(ForkEnv.proxyAdmin), address(ForkEnv.crossMarginService));
    Deployer.upgrade("TradeHelper", address(ForkEnv.proxyAdmin), address(ForkEnv.tradeHelper));
    Deployer.upgrade("ConfigStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.configStorage));

    newOrderReader = new OrderReader(
      address(ForkEnv.configStorage),
      address(ForkEnv.perpStorage),
      address(ForkEnv.oracleMiddleware),
      address(ForkEnv.limitTradeHandler)
    );

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

    priceUpdateData = ForkEnv.ecoPyth2.buildPriceUpdateData(tickPrices);
    publishTimeUpdateData = ForkEnv.ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
  }

  function _setPriceData(
    uint64 _priceE8
  ) internal view returns (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34
    assetIds = new bytes32[](len - 1);
    prices = new uint64[](len - 1);
    shouldInverts = new bool[](len - 1);

    for (uint i = 1; i < len; i++) {
      assetIds[i - 1] = pythRes[i];
      prices[i - 1] = _priceE8 * 1e8;
      if (i == 4) {
        shouldInverts[i - 1] = true; // JPY
      } else {
        shouldInverts[i - 1] = false;
      }
    }
  }

  function _buildDataForPrice() internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();

    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _validateClosedPosition(bytes32 _id) internal {
    IPerpStorage.Position memory _position = ForkEnv.perpStorage.getPositionById(_id);
    // As the position has been closed, the gotten one should be empty stuct
    assertEq(_position.primaryAccount, address(0));
    assertEq(_position.marketIndex, 0);
    assertEq(_position.avgEntryPriceE30, 0);
    assertEq(_position.entryBorrowingRate, 0);
    assertEq(_position.reserveValueE30, 0);
    assertEq(_position.lastIncreaseTimestamp, 0);
    assertEq(_position.positionSizeE30, 0);
    assertEq(_position.realizedPnl, 0);
    assertEq(_position.lastFundingAccrued, 0);
    assertEq(_position.subAccountId, 0);
  }

  function _checkIsUnderMMR(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _limitPriceE30
  ) internal view returns (bool) {
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
    IConfigStorage.MarketConfig memory config = ForkEnv.configStorage.getMarketConfigByIndex(_marketIndex);

    int256 _subAccountEquity = ForkEnv.calculator.getEquity(_subAccount, 0, config.assetId);
    uint256 _mmr = ForkEnv.calculator.getMMR(_subAccount);
    if (_subAccountEquity < 0 || uint256(_subAccountEquity) < _mmr) return true;
    return false;
  }
}
