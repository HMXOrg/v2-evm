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

contract Smoke_TriggerOrder is Smoke_Base {
  address internal constant EXECUTOR = 0xB75ca1CC0B01B6519Bc879756eC431a95DC37882;

  address[] internal accounts;
  uint8[] internal subAccountIds;
  uint256[] internal orderIndexes;

  bytes32[] internal tokenIndexes;

  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_SmokeTest_ExecuteTriggerOrder() external {
    (, , bool[] memory shouldInverts) = _setPriceData(100);
    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();

    uint64[] memory prices = _buildPrice_Triger();

    ILimitTradeHandler.LimitOrder[] memory orders = orderReader.getExecutableOrders(10, 10, prices, shouldInverts);

    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ecoPythBuilder.build(data);

    for (uint i = 0; i < orders.length; i++) {
      if (orders[i].account == address(0)) continue;
      console.log("triggerPrice:", orders[i].triggerPrice);
      console.log("triggerAboveThreshold:", orders[i].triggerAboveThreshold);
      console.log("marketIndex:", orders[i].marketIndex);
      console.log("----------------");
      accounts.push(orders[i].account);
      subAccountIds.push(orders[i].subAccountId);
      orderIndexes.push(orders[i].orderIndex);
    }

    console.log("Valid Orders:", accounts.length);
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
      false
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
  }

  function _buildPrice_Triger() internal returns (uint64[] memory prices) {
    tokenIndexes.push(0x4554480000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4254430000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4141504c00000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4a50590000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x5841550000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x414d5a4e00000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4d53465400000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x54534c4100000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4555520000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x5841470000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4155440000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4742500000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4144410000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4d41544943000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x5355490000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4152420000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4f50000000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4c54430000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x434f494e00000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x474f4f4700000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x424e420000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x534f4c0000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x5151510000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x5852500000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4e56444100000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4c494e4b00000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4348460000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x444f474500000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x4341440000000000000000000000000000000000000000000000000000000000);
    tokenIndexes.push(0x5347440000000000000000000000000000000000000000000000000000000000);

    for (uint i = 0; i < tokenIndexes.length; i++) {
      PythStructs.Price memory _ecoPythPrice = ecoPyth.getPriceUnsafe(tokenIndexes[i]);
      prices[i] = uint64(_ecoPythPrice.price);
    }
  }
}
