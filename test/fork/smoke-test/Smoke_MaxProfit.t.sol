// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";

import "forge-std/console.sol";

contract Smoke_MaxProfit is Smoke_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_SmokeTest_forceCloseMaxProfit() external {
    (, uint64[] memory prices, bool[] memory shouldInverts) = _setPriceData(1);
    (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData) = _setTickPriceZero();

    bytes32[] memory positionIds = ForkEnv.positionReader.getForceTakeMaxProfitablePositionIds(
      10,
      0,
      prices,
      shouldInverts
    );

    if (positionIds.length == 0) {
      console.log("No position to be deleveraged");
      return;
    }

    vm.prank(address(ForkEnv.botHandler));
    ForkEnv.ecoPyth2.updatePriceFeeds(
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    vm.startPrank(POS_MANAGER);
    ForkEnv.botHandler.updateLiquidityEnabled(false);
    for (uint i = 0; i < positionIds.length; i++) {
      IPerpStorage.Position memory _position = ForkEnv.perpStorage.getPositionById(positionIds[i]);
      if (
        _position.primaryAccount == address(0) ||
        _checkIsUnderMMR(
          _position.primaryAccount,
          _position.subAccountId,
          _position.marketIndex,
          _position.avgEntryPriceE30
        )
      ) continue;

      ForkEnv.botHandler.forceTakeMaxProfit(
        _position.primaryAccount,
        _position.subAccountId,
        _position.marketIndex,
        USDC,
        priceUpdateData,
        publishTimeUpdateData,
        block.timestamp,
        keccak256("someEncodedVaas")
      );

      _validateClosedPosition(positionIds[i]);
    }

    ForkEnv.botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }
}
