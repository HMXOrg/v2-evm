// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { IPositionReader } from "@hmx/readers/interfaces/IPositionReader.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

import "forge-std/console.sol";

contract Smoke_MaxProfit is Smoke_Base {
  uint256 internal constant BPS = 10_000;

  address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address internal constant TRADE_SERVICE = 0xcf533D0eEFB072D1BB68e201EAFc5368764daA0E;

  IPositionReader internal positionReader = IPositionReader(0x64706D5f177B892b1cEebe49cd9F02B90BB6FF03);

  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_Smoke_forceCloseMaxProfit() external {
    (, uint64[] memory prices, bool[] memory shouldInverts) = _setPriceData(1);
    (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData) = _setTickPriceZero();

    bytes32[] memory positionIds = positionReader.getForceTakeMaxProfitablePositionIds(10, 0, prices, shouldInverts);

    if (positionIds.length == 0) {
      console.log("No position to be deleveraged");
      return;
    }

    vm.prank(address(botHandler));
    ecoPyth.updatePriceFeeds(priceUpdateData, publishTimeUpdateData, block.timestamp, keccak256("someEncodedVaas"));

    vm.startPrank(POS_MANAGER);
    botHandler.updateLiquidityEnabled(false);
    for (uint i = 0; i < positionIds.length; i++) {
      IPerpStorage.Position memory _position = perpStorage.getPositionById(positionIds[i]);
      if (_position.primaryAccount == address(0)) continue;

      {
        address _subAccount = HMXLib.getSubAccount(_position.primaryAccount, _position.subAccountId);
        IConfigStorage.MarketConfig memory config = configStorage.getMarketConfigByIndex(_position.marketIndex);

        int256 _subAccountEquity = calculator.getEquity(_subAccount, _position.avgEntryPriceE30, config.assetId);
        uint256 _mmr = calculator.getMMR(_subAccount);
        if (_subAccountEquity < 0 || uint256(_subAccountEquity) < _mmr) continue;
      }

      botHandler.forceTakeMaxProfit(
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

    botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }
}
