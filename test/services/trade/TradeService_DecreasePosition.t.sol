// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";
import { ITradeService } from "../../../src/services/interfaces/ITradeService.sol";

contract TradeService_DecreasePosition is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();

    // mock ALICE equity  = 10,000 USD
    mockCalculator.setEquity(10_000 * 1e30);
  }

  // -- pre validation

  // validate market active on perp protocol
  function testRevert_WhenMarketIsDelistedFromPerp() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // delist market
    configStorage.delistMarket(ethMarketIndex);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_MarketIsDelisted.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // validate market status base on pyth network
  function testRevert_WhenOracleTellMarketIsClose() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // set market status from oracle is inactive
    mockOracle.setMarketStatus(1);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_MarketIsClosed.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // validate price stale
  function testRevert_WhenPriceStale() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // note: to check price stale is 30 seconds (hardcode) from published seconds
    vm.warp(block.timestamp + 50);

    vm.expectRevert(
      abi.encodeWithSelector(ITradeService.ITradeService_PriceStale.selector)
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // validate MMR
  function testRevert_WhenSubAccountEquityIsLessThanMMR() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // mock MMR as very big number, to make this sub account unhealthy
    mockCalculator.setMMR(type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_SubAccountEquityIsUnderMMR.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // -- normal case
  // -- LONG position
  // able to decrease long position
  function testCorrectness_WhenTraderDecreaseLongPosition() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 5_00_000 * 1e30);

    // todo: assertion
  }

  function testRevert_TraderDecreaseTooMuchLongPositionSize() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_DecreaseTooHighPositionSize.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_001 * 1e30);
  }

  function testRevert_TraderDecreaseLongPositionWhichAlreadyClosed() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // ALICE close all position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // ALICE try to decrease again
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_PositionAlreadyClosed.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);
  }

  // validate too tiny remaining position size
  function testRevert_RemainingLongPositionSizeIsTooTiny() external {
    // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_TooTinyPosition.selector
      )
    );
    // decrease position for 999,999.9
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 9_999_999 * 1e29);
  }

  // -- SHORT position
  // able to decrease short position
  function testCorrectness_WhenTraderDecreaseShortPosition() external {
    // ALICE open SHORT position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // cache position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    IPerpStorage.Position memory _position = perpStorage.getPositionById(
      _positionId
    );
    assertEq(_position.positionSizeE30, -1_000_000 * 1e30);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 5_00_000 * 1e30);

    // todo: assertion
  }

  function testRevert_TraderDecreaseTooMuchShortPositionSize() external {
    // ALICE open SHORT position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_DecreaseTooHighPositionSize.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_001 * 1e30);
  }

  function testRevert_TraderDecreaseShortPositionWhichAlreadyClosed() external {
    // ALICE open SHORT position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // ALICE close all position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // ALICE try to decrease again
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_PositionAlreadyClosed.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);
  }

  // validate too tiny remaining position size
  function testRevert_RemainingShortPositionSizeIsTooTiny() external {
    // ALICE open SHORT position at sub account 0 with size 1,000,000 USD on max Leverage
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_TooTinyPosition.selector
      )
    );
    // decrease position for 999,999.9
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 9_999_999 * 1e29);
  }

  // -- borrowing fee
  // -- funding fee
  // -- settlement
  // profit
  // loss
  // -- post validation

  // validate MMR in post validation
  // note: this case need to open many position and then decrease 1 with a lot of loss size
  //       now we still not support about settle profit and loss todo: make this test valid
  // function testRevert_AfterPositionDecreasedAndSubAccountEquityIsLessThanMMR()
  //   external
  // {
  //   // ALICE open LONG position at sub account 0 with size 1,000,000 USD on max Leverage
  //   openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       ITradeService.ITradeService_SubAccountEquityIsUnderMMR.selector
  //     )
  //   );
  //   tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  // }
}
