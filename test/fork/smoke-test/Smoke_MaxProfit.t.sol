// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { console } from "forge-std/console.sol";
import { UncheckedEcoPythCalldataBuilder } from "@hmx/oracles/UncheckedEcoPythCalldataBuilder.sol";

contract Smoke_MaxProfit is ForkEnv {
  error Smoke_MaxProfit_NoPosition();
  error Smoke_MaxProfit_NoFilteredPosition();

  UncheckedEcoPythCalldataBuilder uncheckedBuilder;

  constructor() {
    uncheckedBuilder = new UncheckedEcoPythCalldataBuilder(ForkEnv.ecoPyth2, ForkEnv.glpManager, ForkEnv.sglp);
  }

  function forceCloseMaxProfit() external {
    IPerpStorage.Position[] memory positions = ForkEnv.perpStorage.getActivePositions(10, 0);

    IPerpStorage.Position memory position;
    for (uint256 i; i < positions.length; i++) {
      // take one long position only, as short position might be impossible for max profit
      if (positions[i].positionSizeE30 > 0) {
        position = positions[i];
        break;
      }
    }
    bool isLong = position.positionSizeE30 > 0;
    int256 maxProfitPrice;
    if (isLong) {
      // (maxProfitPrice - avgEntryPriceE30) / avgEntryPriceE30 * positionSizeE30 = reserveValueE30
      // maxProfitPrice = (avgEntryPriceE30 * (reserveValueE30 + positionSizeE30) / positionSizeE30
      maxProfitPrice =
        (int256(position.avgEntryPriceE30) * (int256(position.reserveValueE30) + position.positionSizeE30)) /
        position.positionSizeE30;
      maxProfitPrice = (maxProfitPrice * 1100) / 1000; // bump price up a bit to avoid tick price precision loss
    } else {
      // (avgEntryPriceE30 - maxProfitPrice) / avgEntryPriceE30 * positionSizeE30 = reserveValueE30
      // maxProfitPrice = avgEntryPriceE30 - ((avgEntryPriceE30 * reserveValueE30) / positionSizeE30)
      maxProfitPrice =
        int256(position.avgEntryPriceE30) -
        ((int256(position.avgEntryPriceE30) * int256(position.reserveValueE30)) / position.positionSizeE30);
      maxProfitPrice = (maxProfitPrice * 900) / 1000; // bump price down a bit to avoid tick price precision loss
    }

    IConfigStorage.MarketConfig memory config = ForkEnv.configStorage.getMarketConfigByIndex(position.marketIndex);
    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPriceWithSpecificPrice(
      config.assetId,
      int64(maxProfitPrice / 1e22)
    );
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = uncheckedBuilder.build(data);

    vm.startPrank(ForkEnv.positionManager);
    ForkEnv.botHandler.updateLiquidityEnabled(false);

    ForkEnv.botHandler.forceTakeMaxProfit(
      position.primaryAccount,
      position.subAccountId,
      position.marketIndex,
      address(ForkEnv.usdc_e),
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("someEncodedVaas")
    );

    bytes32 positionId = HMXLib.getPositionId(
      HMXLib.getSubAccount(position.primaryAccount, position.subAccountId),
      position.marketIndex
    );
    _validateClosedPosition(positionId);

    ForkEnv.botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }
}
