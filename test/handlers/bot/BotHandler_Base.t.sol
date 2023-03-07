// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "../../base/BaseTest.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";

import { TradeService } from "../../../src/services/TradeService.sol";

import { BotHandler } from "../../../src/handlers/BotHandler.sol";

import { PositionTester } from "../../testers/PositionTester.sol";
import { PositionTester02 } from "../../testers/PositionTester02.sol";
import { GlobalMarketTester } from "../../testers/GlobalMarketTester.sol";

contract BotHandler_Base is BaseTest {
  TradeService tradeService;
  PositionTester positionTester;
  PositionTester02 positionTester02;
  GlobalMarketTester globalMarketTester;

  BotHandler botHandler;
  bytes[] prices;

  function setUp() public virtual {
    // setup for trade service
    prices = new bytes[](0);

    configStorage.setCalculator(address(mockCalculator));
    positionTester = new PositionTester(perpStorage, vaultStorage, mockOracle);
    positionTester02 = new PositionTester02(perpStorage);
    globalMarketTester = new GlobalMarketTester(perpStorage);

    // deploy services
    tradeService = new TradeService(address(perpStorage), address(vaultStorage), address(configStorage));

    botHandler = deployBotHandler(address(tradeService), address(mockLiquidationService), address(mockPyth));

    address[] memory _positionManagers = new address[](1);
    _positionManagers[0] = address(this);

    // set Tester as position manangers
    botHandler.setPositionManagers(_positionManagers, true);
    configStorage.setServiceExecutor(address(tradeService), address(this), true);
  }

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  function _getPositionId(address _account, uint8 _subAccountId, uint256 _marketIndex) internal pure returns (bytes32) {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }
}
