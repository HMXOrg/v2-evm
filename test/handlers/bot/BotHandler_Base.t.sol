// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "../../base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";

import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";

import { PositionTester } from "../../testers/PositionTester.sol";
import { PositionTester02 } from "../../testers/PositionTester02.sol";
import { GlobalMarketTester } from "../../testers/GlobalMarketTester.sol";

contract BotHandler_Base is BaseTest {
  ITradeService tradeService;

  PositionTester positionTester;
  PositionTester02 positionTester02;
  GlobalMarketTester globalMarketTester;

  IBotHandler botHandler;
  bytes[] prices;

  function setUp() public virtual {
    // setup for trade service
    prices = new bytes[](0);

    configStorage.setCalculator(address(mockCalculator));
    positionTester = new PositionTester(perpStorage, vaultStorage, mockOracle);
    positionTester02 = new PositionTester02(perpStorage);
    globalMarketTester = new GlobalMarketTester(perpStorage);

    // deploy services
    tradeService = ITradeService(
      Deployer.deployContractWithArguments(
        "TradeService",
        abi.encode(address(perpStorage), address(vaultStorage), address(configStorage))
      )
    );

    botHandler = deployBotHandler(address(tradeService), address(mockLiquidationService), address(mockPyth));

    address[] memory _positionManagers = new address[](1);
    _positionManagers[0] = address(this);

    // set Tester as position manangers
    botHandler.setPositionManagers(_positionManagers, true);
    configStorage.setServiceExecutor(address(tradeService), address(this), true);
  }

  function _getSubAccount(address primary, uint256 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  function _getPositionId(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex
  ) internal pure returns (bytes32) {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }
}
