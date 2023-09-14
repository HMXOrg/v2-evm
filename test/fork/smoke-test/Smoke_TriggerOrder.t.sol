// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";

import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

import "forge-std/console.sol";

contract Smoke_TriggerOrder is Smoke_Base {
  address internal constant EXECUTOR = 0xB75ca1CC0B01B6519Bc879756eC431a95DC37882;

  address[] internal accounts;
  uint8[] internal subAccountIds;
  uint256[] internal orderIndexes;

  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_Smoke_ExecuteTriggerOrder() external {
    (, , bool[] memory shouldInverts) = _setPriceData(100);
    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();

    uint64[] memory prices = new uint64[](data.length);
    for (uint i = 0; i < data.length; i++) {
      prices[i] = uint64(data[i].priceE8) / 2;
    }

    ILimitTradeHandler.LimitOrder[] memory orders = orderReader.getExecutableOrders(10, 0, prices, shouldInverts);
    console.log("executable order:", orders.length);

    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ecoPythBuilder.build(data);

    for (uint i = 0; i < orders.length; i++) {
      console.log(i, orders[i].account);
      if (orders[i].account == address(0)) continue;
      accounts.push(orders[i].account);
      subAccountIds.push(orders[i].subAccountId);
      orderIndexes.push(orders[i].orderIndex);
    }

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
  }
}
