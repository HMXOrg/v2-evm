// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { PositionTester } from "../../testers/PositionTester.sol";
import { PositionTester02 } from "../../testers/PositionTester02.sol";
import { GlobalMarketTester } from "../../testers/GlobalMarketTester.sol";

import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ILiquidationService } from "@hmx/services/interfaces/ILiquidationService.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

abstract contract LiquidationService_Base is BaseTest {
  ITradeService tradeService;
  ILiquidationService liquidationService;
  PositionTester positionTester;
  PositionTester02 positionTester02;
  GlobalMarketTester globalMarketTester;

  function setUp() public virtual {
    configStorage.setCalculator(address(mockCalculator));
    positionTester = new PositionTester(perpStorage, vaultStorage, mockOracle);
    positionTester02 = new PositionTester02(perpStorage);
    globalMarketTester = new GlobalMarketTester(perpStorage);

    // deploy services
    tradeService = Deployer.deployTradeService(address(perpStorage), address(vaultStorage), address(configStorage));

    configStorage.setServiceExecutor(address(tradeService), address(this), true);
    liquidationService = Deployer.deployLiquidationService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );
  }

  function getSubAccount(address _account, uint8 _subAccountId) internal pure returns (address) {
    return address(uint160(_account) ^ uint160(_subAccountId));
  }

  function getPositionId(address _account, uint8 _subAccountId, uint256 _marketIndex) internal pure returns (bytes32) {
    address _subAccount = getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }
}
