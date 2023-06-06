// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try set tradeService with address zero
//   - Try set min execution fee exceeding max execution fee
//   - Try set Pyth address with address zero
// - success
//   - Try set tradeService
//   - Try set min execution
//   - Try set Pyth address
//   - Try set order executor

contract LimitTradeHandler_Setter is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();
  }

  // Set trade service with zero address
  function testRevert_setTradeService_AddressZero() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_InvalidAddress()"));
    limitTradeHandler.setTradeService(address(0));
  }

  function testCorrectness_setTradeService() external {
    limitTradeHandler.setTradeService(address(mockTradeService));
    assertEq(limitTradeHandler.tradeService(), address(mockTradeService));
  }

  function testRevert_setMinExecutionFee_MaxExecutionFee() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_MaxExecutionFee()"));
    limitTradeHandler.setMinExecutionFee(6 ether);
  }

  function testCorrectness_setMinExecutionFee() external {
    limitTradeHandler.setMinExecutionFee(1 ether);

    assertEq(limitTradeHandler.minExecutionFee(), 1 ether);
  }

  function testCorrectness_setOrderExecutor() external {
    limitTradeHandler.setOrderExecutor(ALICE, true);
    assertEq(limitTradeHandler.orderExecutors(ALICE), true);

    limitTradeHandler.setOrderExecutor(ALICE, false);
    assertEq(limitTradeHandler.orderExecutors(ALICE), false);
  }

  function testRevert_setPyth_AddressZero() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_InvalidAddress()"));
    limitTradeHandler.setPyth(address(0));
  }
}
