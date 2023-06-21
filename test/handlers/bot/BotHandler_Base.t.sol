// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";

import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";

import { PositionTester } from "../../testers/PositionTester.sol";
import { PositionTester02 } from "../../testers/PositionTester02.sol";
import { MarketTester } from "../../testers/MarketTester.sol";

contract BotHandler_Base is BaseTest {
  ITradeHelper tradeHelper;

  ITradeService tradeService;

  PositionTester positionTester;
  PositionTester02 positionTester02;
  MarketTester globalMarketTester;

  IBotHandler botHandler;
  bytes[] prices;

  int24[] internal tickPrices;
  uint24[] internal publishTimeDiffs;
  bytes32[] internal priceUpdateData;
  bytes32[] internal publishTimeUpdateData;

  function setUp() public virtual {
    // setup for trade service
    prices = new bytes[](0);

    priceUpdateData = ecoPyth.buildPriceUpdateData(tickPrices);
    publishTimeUpdateData = ecoPyth.buildPublishTimeUpdateData(publishTimeDiffs);

    configStorage.setCalculator(address(mockCalculator));
    positionTester = new PositionTester(perpStorage, vaultStorage, mockOracle);
    positionTester02 = new PositionTester02(perpStorage);
    globalMarketTester = new MarketTester(perpStorage);

    tradeHelper = Deployer.deployTradeHelper(
      address(proxyAdmin),
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );

    // deploy services
    tradeService = Deployer.deployTradeService(
      address(proxyAdmin),
      address(perpStorage),
      address(vaultStorage),
      address(configStorage),
      address(tradeHelper)
    );

    botHandler = Deployer.deployBotHandler(
      address(proxyAdmin),
      address(tradeService),
      address(mockLiquidationService),
      address(mockCrossMarginService),
      address(ecoPyth)
    );
    ecoPyth.setUpdater(address(botHandler), true);

    address[] memory _positionManagers = new address[](1);
    _positionManagers[0] = address(this);

    // set Tester as position managers
    botHandler.setPositionManagers(_positionManagers, true);
    configStorage.setServiceExecutor(address(tradeService), address(this), true);
    configStorage.setServiceExecutor(address(tradeHelper), address(tradeService), true);
    configStorage.setServiceExecutor(address(tradeHelper), address(mockLiquidationService), true);

    // Set whitelist for service executor
    configStorage.setServiceExecutor(address(tradeService), address(botHandler), true);
    perpStorage.setServiceExecutors(address(tradeService), true);
    perpStorage.setServiceExecutors(address(tradeHelper), true);

    vaultStorage.setServiceExecutors(address(tradeService), true);
    vaultStorage.setServiceExecutors(address(tradeHelper), true);
    vaultStorage.setServiceExecutors(address(this), true);
  }

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  function _getPositionId(address _account, uint8 _subAccountId, uint256 _marketIndex) internal pure returns (bytes32) {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }
}
