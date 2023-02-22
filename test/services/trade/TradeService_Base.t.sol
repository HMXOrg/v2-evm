// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { BaseTest } from "../../base/BaseTest.sol";

import { PositionTester } from "../../testers/PositionTester.sol";

import { TradeService } from "../../../src/services/TradeService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

abstract contract TradeService_Base is BaseTest {
  TradeService tradeService;

  PositionTester positionTester;

  function setUp() public virtual {
    positionTester = new PositionTester(perpStorage, vaultStorage, mockOracle);

    // deploy services
    tradeService = new TradeService(address(perpStorage), address(vaultStorage), address(configStorage));
  }

  function getPositionId(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex
  ) internal pure returns (bytes32) {
    address _subAccount = address(uint160(_account) ^ uint160(_subAccountId));
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }

  function openPosition(address _account, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeE30) internal {
    tradeService.increasePosition(_account, _subAccountId, _marketIndex, _sizeE30);
  }
}
