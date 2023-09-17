// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";

import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";

import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

import "forge-std/console.sol";
import "forge-std/console2.sol";

contract Smoke_TriggerOrder is Smoke_Base {
  error Smoke_TriggerOrder_NoOrder();

  address[] internal accounts;
  uint8[] internal subAccountIds;
  uint256[] internal orderIndexes;

  address[] internal executeAccounts;
  uint8[] internal executeSubAccountIds;
  uint256[] internal executeOrderIndexes;

  function setUp() public virtual override {
    super.setUp();
  }

  function testCheck_SmokeTrigger() external view {
    console2.logBytes(abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()"));
  }

  function testCorrectness_SmokeTest_ExecuteTriggerOrder() external {
    (, , bool[] memory shouldInverts) = _setPriceData(1);

    ILimitTradeHandler.LimitOrder memory _order;

    ILimitTradeHandler.LimitOrder[] memory activeOrders = ForkEnv.limitTradeHandler.getAllActiveOrders(10, 0);

    for (uint i = 0; i < activeOrders.length; i++) {
      if (
        activeOrders[i].account != address(0) &&
        activeOrders[i].marketIndex != 3 && // Ignore JPY, too complicated with invert
        (activeOrders[i].sizeDelta == type(int256).max || // focus only TP
          activeOrders[i].sizeDelta == type(int256).min) // focus only SL
      ) {
        accounts.push(activeOrders[i].account);
        subAccountIds.push(activeOrders[i].subAccountId);
        orderIndexes.push(activeOrders[i].orderIndex);
        _order = activeOrders[i];
      }
      if (accounts.length > 0) break;
    }

    if (accounts.length == 0) {
      console.log("No order to be triggered");
      revert Smoke_TriggerOrder_NoOrder();
    }

    uint64[] memory prices = new uint64[](30);
    prices = _buildPrice_Trigger(_order.marketIndex, _order.triggerPrice, _order.triggerAboveThreshold);
    ILimitTradeHandler.LimitOrder[] memory readerOrders = ForkEnv.orderReader.getExecutableOrders(
      10,
      0,
      prices,
      shouldInverts
    );

    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice_Trigger(
      _order.marketIndex,
      _order.triggerPrice,
      _order.triggerAboveThreshold
    );

    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ForkEnv.ecoPythBuilder.build(data);

    for (uint i = 0; i < readerOrders.length; i++) {
      if (readerOrders[i].account == address(0)) continue;
      executeAccounts.push(readerOrders[i].account);
      executeSubAccountIds.push(readerOrders[i].subAccountId);
      executeOrderIndexes.push(readerOrders[i].orderIndex);
    }

    vm.prank(address(ForkEnv.botHandler));
    ForkEnv.ecoPyth2.updatePriceFeeds(
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    vm.prank(EXECUTOR);
    ForkEnv.limitTradeHandler.executeOrders(
      executeAccounts,
      executeSubAccountIds,
      executeOrderIndexes,
      payable(EXECUTOR),
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("someEncodedVaas"),
      true
    );

    _validateExecutedOrder(executeAccounts, executeSubAccountIds, executeOrderIndexes);
  }

  function _validateExecutedOrder(
    address[] memory _accounts,
    uint8[] memory _subAccountIds,
    uint256[] memory _orderIndexes
  ) internal {
    for (uint i = 0; i < _accounts.length; i++) {
      address subAccount = HMXLib.getSubAccount(accounts[i], _subAccountIds[i]);

      // order should be deleted
      (address account, , , , , , , , , , , ) = ForkEnv.limitTradeHandler.limitOrders(subAccount, _orderIndexes[i]);
      assertEq(account, address(0));
    }
    console.log("validated");
  }

  function _buildDataForPrice_Trigger(
    uint256 _marketIndex,
    uint256 _triggerPrice,
    bool _above
  ) internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();

    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(pythRes[i]);
      IConfigStorage.MarketConfig memory marketConfig = ForkEnv.configStorage.getMarketConfigByIndex(_marketIndex);

      if (marketConfig.assetId == pythRes[i]) {
        if (_above) {
          data[i - 1].priceE8 = int64(int256(((_triggerPrice * 10001) / 10000) / 1e22)); // 105% of trigger
        } else {
          data[i - 1].priceE8 = int64(int256(((_triggerPrice * 9999) / 10000) / 1e22)); // 95% of trigger
        }
      } else data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].assetId = pythRes[i];
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _buildPrice_Trigger(
    uint256 _marketIndex,
    uint256 _triggerPrice,
    bool _above
  ) internal view returns (uint64[] memory prices) {
    bytes32[] memory tokenIndexes = new bytes32[](30);
    prices = new uint64[](30);

    tokenIndexes[0] = 0x4554480000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[1] = 0x4254430000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[2] = 0x4141504c00000000000000000000000000000000000000000000000000000000;
    tokenIndexes[3] = 0x4a50590000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[4] = 0x5841550000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[5] = 0x414d5a4e00000000000000000000000000000000000000000000000000000000;
    tokenIndexes[6] = 0x4d53465400000000000000000000000000000000000000000000000000000000;
    tokenIndexes[7] = 0x54534c4100000000000000000000000000000000000000000000000000000000;
    tokenIndexes[8] = 0x4555520000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[9] = 0x5841470000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[10] = 0x4155440000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[11] = 0x4742500000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[12] = 0x4144410000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[13] = 0x4d41544943000000000000000000000000000000000000000000000000000000;
    tokenIndexes[14] = 0x5355490000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[15] = 0x4152420000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[16] = 0x4f50000000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[17] = 0x4c54430000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[18] = 0x434f494e00000000000000000000000000000000000000000000000000000000;
    tokenIndexes[19] = 0x474f4f4700000000000000000000000000000000000000000000000000000000;
    tokenIndexes[20] = 0x424e420000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[21] = 0x534f4c0000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[22] = 0x5151510000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[23] = 0x5852500000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[24] = 0x4e56444100000000000000000000000000000000000000000000000000000000;
    tokenIndexes[25] = 0x4c494e4b00000000000000000000000000000000000000000000000000000000;
    tokenIndexes[26] = 0x4348460000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[27] = 0x444f474500000000000000000000000000000000000000000000000000000000;
    tokenIndexes[28] = 0x4341440000000000000000000000000000000000000000000000000000000000;
    tokenIndexes[29] = 0x5347440000000000000000000000000000000000000000000000000000000000;

    for (uint i = 0; i < 30; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(tokenIndexes[i]);
      IConfigStorage.MarketConfig memory marketConfig = ForkEnv.configStorage.getMarketConfigByIndex(_marketIndex);
      if (marketConfig.assetId == tokenIndexes[i]) {
        if (_above) {
          prices[i] = uint64(((_triggerPrice * 10001) / 10000) / 1e22); // 100.01% of trigger
        } else {
          prices[i] = uint64(((_triggerPrice * 9999) / 10000) / 1e22); // 99.99% of trigger
        }
      } else prices[i] = uint64(_ecoPythPrice.price);
    }
  }
}
