// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

import "forge-std/console.sol";

contract Smoke_Liquidate is Smoke_Base {
  uint256 internal constant BPS = 10_000;

  address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address internal constant TRADE_SERVICE = 0xcf533D0eEFB072D1BB68e201EAFc5368764daA0E;

  function setUp() public virtual override {
    super.setUp();

    vm.prank(OWNER);
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 30, // 0.3%
        withdrawFeeRateBPS: 30, // 0.3%
        maxHLPUtilizationBPS: 8000, // 80%
        hlpTotalTokenWeight: 0,
        hlpSafetyBufferBPS: 10000, // 100%
        taxFeeRateBPS: 50, // 0.5%
        flashLoanFeeRateBPS: 0,
        dynamicFeeEnabled: true,
        enabled: true
      })
    );
  }

  function testCorrectness_SmokeTest_deleverageFirstTen() external {
    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice_Deleverage();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ecoPythBuilder.build(data);

    IPerpStorage.Position[] memory positions = perpStorage.getActivePositions(10, 0);

    if (positions.length == 0) {
      console.log("No position to be deleveraged");
      return;
    }

    vm.startPrank(POS_MANAGER);
    botHandler.updateLiquidityEnabled(false);
    for (uint i = 0; i < positions.length; i++) {
      if (positions[i].primaryAccount == address(0)) continue; // if address(0), ignore.

      address subAccount = HMXLib.getSubAccount(positions[i].primaryAccount, positions[i].subAccountId);
      bytes32 positionId = HMXLib.getPositionId(subAccount, positions[i].marketIndex);

      botHandler.deleverage(
        positions[i].primaryAccount,
        positions[i].subAccountId,
        positions[i].marketIndex,
        USDC,
        _priceUpdateCalldata,
        _publishTimeUpdateCalldata,
        _minPublishTime,
        keccak256("someEncodedVaas")
      );

      _validateClosedPosition(positionId);
    }
    botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }

  function _buildDataForPrice_Deleverage() internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ecoPyth.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ecoPyth.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 20_000;
      if (i == 1) {
        data[i - 1].priceE8 = _ecoPythPrice.price * 2;
      } else {
        data[i - 1].priceE8 = _ecoPythPrice.price;
      }
    }
  }

  /// @dev: This is for the case, bug as some will be reverted,
  ///       due to equity is under MMR, which should be liquidated instead.
  // function testCorrectness_Smoke_deleverageAsAPI() external {
  //   IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();
  //   (
  //     uint256 _minPublishTime,
  //     bytes32[] memory _priceUpdateCalldata,
  //     bytes32[] memory _publishTimeUpdateCalldata
  //   ) = ecoPythBuilder.build(data);

  //   vm.startPrank(POS_MANAGER);
  //   // API uses MAX, but will restrict it to 10k at most due to test efficiency
  //   botHandler.updateLiquidityEnabled(false);
  //   for (uint chunk = 0; chunk < 100; chunk++) {
  //     IPerpStorage.Position[] memory positions = perpStorage.getActivePositions(100, 0);
  //     if (positions.length == 0) {
  //       console.log("No position to be deleveraged");
  //       return;
  //     }

  //     for (uint i = 0; i < positions.length; i++) {
  //       if (positions[i].primaryAccount == address(0)) continue; // if address(0), ignore.

  //       address subAccount = HMXLib.getSubAccount(positions[i].primaryAccount, positions[i].subAccountId);
  //       bytes32 positionId = HMXLib.getPositionId(subAccount, positions[i].marketIndex);

  //       botHandler.deleverage(
  //         positions[i].primaryAccount,
  //         positions[i].subAccountId,
  //         positions[i].marketIndex,
  //         USDC,
  //         _priceUpdateCalldata,
  //         _publishTimeUpdateCalldata,
  //         _minPublishTime,
  //         keccak256("someEncodedVaas")
  //       );

  //       IPerpStorage.Position memory _position = perpStorage.getPositionById(positionId);
  //       // As the position has been closed, the gotten one should be empty stuct
  //       assertEq(_position.primaryAccount, address(0));
  //       assertEq(_position.marketIndex, 0);
  //       assertEq(_position.avgEntryPriceE30, 0);
  //       assertEq(_position.entryBorrowingRate, 0);
  //       assertEq(_position.reserveValueE30, 0);
  //       assertEq(_position.lastIncreaseTimestamp, 0);
  //       assertEq(_position.positionSizeE30, 0);
  //       assertEq(_position.realizedPnl, 0);
  //       assertEq(_position.lastFundingAccrued, 0);
  //       assertEq(_position.subAccountId, 0);
  //     }
  //     console.log("Chunk:", chunk);
  //   }
  //   botHandler.updateLiquidityEnabled(true);
  //   vm.stopPrank();
  //   console.log("PASSED");
  //   return;
  // }
}
