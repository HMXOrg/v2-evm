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
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";

import "forge-std/console.sol";

contract Smoke_Liquidate is Smoke_Base {
  error Smoke_Liquidate_NoPosition();
  error Smoke_Liquidate_NoFilteredPosition();

  IPerpStorage.Position[] internal filteredPositions;

  function setUp() public virtual override {
    super.setUp();

    vm.prank(OWNER);
    ForkEnv.configStorage.setLiquidityConfig(
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

  function testCorrectness_SmokeTest_deleverage() external {
    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice_Deleverage();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ForkEnv.ecoPythBuilder.build(data);

    vm.prank(address(ForkEnv.botHandler));
    ForkEnv.ecoPyth2.updatePriceFeeds(
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("someEncodedVaas")
    );
    IPerpStorage.Position[] memory positions = ForkEnv.perpStorage.getActivePositions(5, 0);

    if (positions.length == 0) {
      revert Smoke_Liquidate_NoPosition();
    }

    vm.startPrank(address(ForkEnv.tradeService));
    ForkEnv.vaultStorage.removeHlpLiquidityDebtUSDE30(ForkEnv.vaultStorage.hlpLiquidityDebtUSDE30());
    vm.stopPrank();

    for (uint i = 0; i < positions.length; i++) {
      if (
        positions[i].primaryAccount == address(0) ||
        _checkIsUnderMMR(
          positions[i].primaryAccount,
          positions[i].subAccountId,
          positions[i].marketIndex,
          positions[i].avgEntryPriceE30
        ) ||
        positions[i].marketIndex != 1 // NOTE on test, focus for ETH pos only, avoid price conflict
      ) continue;
      filteredPositions.push(positions[i]);
    }

    vm.startPrank(address(ForkEnv.tradeService));
    ForkEnv.vaultStorage.removeHlpLiquidityDebtUSDE30(ForkEnv.vaultStorage.hlpLiquidityDebtUSDE30());
    vm.stopPrank();

    if (positions.length == 0) {
      revert Smoke_Liquidate_NoFilteredPosition();
    }

    vm.startPrank(POS_MANAGER);
    ForkEnv.botHandler.updateLiquidityEnabled(false);
    for (uint i = 0; i < filteredPositions.length; i++) {
      address subAccount = HMXLib.getSubAccount(filteredPositions[i].primaryAccount, filteredPositions[i].subAccountId);
      bytes32 positionId = HMXLib.getPositionId(subAccount, filteredPositions[i].marketIndex);

      console.log("Start delevaraging...");
      ForkEnv.botHandler.deleverage(
        filteredPositions[i].primaryAccount,
        filteredPositions[i].subAccountId,
        filteredPositions[i].marketIndex,
        USDC,
        _priceUpdateCalldata,
        _publishTimeUpdateCalldata,
        _minPublishTime,
        keccak256("someEncodedVaas")
      );
      console.log("done");

      _validateClosedPosition(positionId);
    }
    ForkEnv.botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }

  function _buildDataForPrice_Deleverage() internal view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
    bytes32[] memory pythRes = ForkEnv.ecoPyth2.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ForkEnv.ecoPyth2.getPriceUnsafe(pythRes[i]);
      data[i - 1].assetId = pythRes[i];
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 20_000;
      if (i == 1) {
        // ETH
        data[i - 1].priceE8 = _ecoPythPrice.price * 2;
      } else {
        data[i - 1].priceE8 = _ecoPythPrice.price;
      }
    }
  }
}
