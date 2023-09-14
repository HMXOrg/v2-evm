// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";

import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

import "forge-std/console.sol";
import "forge-std/console2.sol";

contract Smoke_TriggerOrder is Smoke_Base {
  address internal constant EXECUTOR = 0xB75ca1CC0B01B6519Bc879756eC431a95DC37882;

  address[] internal accounts;
  uint8[] internal subAccountIds;
  uint256[] internal orderIndexes;

  function setUp() public virtual override {
    super.setUp();
  }

  function testCheck_SmokeTrigger() external view {
    console2.logBytes(abi.encodeWithSignature("ILimitTradeHandler_InvalidPriceForExecution()"));
  }

  function testCorrectness_SmokeTest_ExecuteTriggerOrder() external {
    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice_Trigger();

    for (uint chunk = 0; chunk < 100; chunk++) {
      ILimitTradeHandler.LimitOrder[] memory orders = limitHandler.getAllActiveOrders(5, chunk);

      for (uint i = 0; i < orders.length; i++) {
        if (
          orders[i].account == address(0) ||
          !orders[i].triggerAboveThreshold ||
          orders[i].sizeDelta == type(int256).max || // TP
          orders[i].sizeDelta == type(int256).min // SL
        ) continue;
        accounts.push(orders[i].account);
        subAccountIds.push(orders[i].subAccountId);
        orderIndexes.push(orders[i].orderIndex);
      }

      if (accounts.length > 0) break;
    }

    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ecoPythBuilder.build(data);

    vm.prank(address(botHandler));
    ecoPyth.updatePriceFeeds(
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    vm.prank(EXECUTOR);
    limitHandler.executeOrders(
      accounts,
      subAccountIds,
      orderIndexes,
      payable(EXECUTOR),
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("someEncodedVaas"),
      true
    );

    _validateExecutedOrder();
  }

  function _validateExecutedOrder() internal {
    for (uint i = 0; i < accounts.length; i++) {
      address subAccount = HMXLib.getSubAccount(accounts[i], subAccountIds[i]);

      // order should be deleted
      (address account, , , , , , , , , , , ) = limitHandler.limitOrders(subAccount, orderIndexes[i]);
      assertEq(account, address(0));
    }
    console.log("validated");
  }

  function _buildDataForPrice_Trigger() internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ecoPyth.getAssetIds();

    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ecoPyth.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      if (pythRes[i] == 0x444f474500000000000000000000000000000000000000000000000000000000) {
        data[i - 1].priceE8 = 6300591; // DOGE, approx to 0.063$; valid for order
        console.log(uint64(data[i - 1].priceE8));
      } else data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }
}
