// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { PositionTester } from "@hmx-test/testers/PositionTester.sol";
import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";
import { GlobalMarketTester } from "@hmx-test/testers/GlobalMarketTester.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

abstract contract TradeService_Base is BaseTest {
  ITradeHelper tradeHelper;
  ITradeService tradeService;

  PositionTester positionTester;
  PositionTester02 positionTester02;
  GlobalMarketTester globalMarketTester;

  function setUp() public virtual {
    configStorage.setCalculator(address(mockCalculator));
    positionTester = new PositionTester(perpStorage, vaultStorage, mockOracle);
    positionTester02 = new PositionTester02(perpStorage);
    globalMarketTester = new GlobalMarketTester(perpStorage);

    tradeHelper = Deployer.deployTradeHelper(address(perpStorage), address(vaultStorage), address(configStorage));
    // deploy services
    tradeService = Deployer.deployTradeService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage),
      address(tradeHelper)
    );
    configStorage.setServiceExecutor(address(tradeService), address(this), true);
    configStorage.setServiceExecutor(address(tradeHelper), address(tradeService), true);

    perpStorage.setServiceExecutors(address(tradeService), true);
    perpStorage.setServiceExecutors(address(tradeHelper), true);

    vaultStorage.setServiceExecutors(address(tradeService), true);
    vaultStorage.setServiceExecutors(address(tradeHelper), true);
    vaultStorage.setServiceExecutors(address(this), true);
  }

  function getSubAccount(address _account, uint8 _subAccountId) internal pure returns (address) {
    return address(uint160(_account) ^ uint160(_subAccountId));
  }

  function getPositionId(address _account, uint8 _subAccountId, uint256 _marketIndex) internal pure returns (bytes32) {
    address _subAccount = getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }
}
