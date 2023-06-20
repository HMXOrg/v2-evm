// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

// What is this test DONE
// - success
//   - Try get Unrealized PNL with no opening position on trader's sub account
//   - Try get Unrealized PNL with LONG opening position with PROFIT on trader's sub account
//   - Try get Unrealized PNL with LONG opening position with LOSS on trader's sub account
//   - Try get Unrealized PNL with SHORT opening position with PROFIT on trader's sub account
//   - Try get Unrealized PNL with SHORT opening position with LOSS on trader's sub account
// What is this test not covered
//   - Price Stale checking from Oracle

contract Calculator_GetDelta is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testRevert_getDelta_WhenBadAveragePrice() external {
    // Bad position average price
    uint256 avgPriceE30 = 0;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    (, uint256 delta) = calculator.getDelta(size, isLong, 1e30, avgPriceE30, 0);

    // So that, we expect getDelta to gracefully return 0 instead of revert.
    assertEq(delta, 0 ether);
  }

  function testCorrectness_getDelta_WhenLongAndPriceUp() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 24_200 * 1e30;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    // price up 10% -> profit 10% of size
    (bool isProfit, uint256 delta) = calculator.getDelta(size, isLong, nextPrice, avgPriceE30, 0);

    assertEq(isProfit, true);
    assertEq(delta, 100 * 1e30);
  }

  function testCorrectness_getDelta_WhenLongAndPriceDown() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 18_700 * 1e30;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    // price down 15% -> loss 15% of size
    (bool isProfit, uint256 delta) = calculator.getDelta(size, isLong, nextPrice, avgPriceE30, 0);

    assertEq(isProfit, false);
    assertEq(delta, 150 * 1e30);
  }

  function testCorrectness_getDelta_WhenShortAndPriceUp() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 23_100 * 1e30;
    bool isLong = false;
    uint256 size = 1_000 * 1e30;

    // price up 5% -> loss 5% of size
    (bool isProfit, uint256 delta) = calculator.getDelta(size, isLong, nextPrice, avgPriceE30, 0);

    assertEq(isProfit, false);
    assertEq(delta, 50 * 1e30);
  }

  function testCorrectness_getDelta_WhenShortAndPriceDown() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 11_000 * 1e30;
    bool isLong = false;
    uint256 size = 1_000 * 1e30;

    // price down 50% -> profit 50% of size
    (bool isProfit, uint256 delta) = calculator.getDelta(size, isLong, nextPrice, avgPriceE30, 0);

    assertEq(isProfit, true);
    assertEq(delta, 500 * 1e30);
  }

  function testCorrectness_getDelta_WhenProfit_ButHaventSurpassMinProfitDuration() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 33_000 * 1e30;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    // Set minProfitDuration = 30 secs
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({
        fundingInterval: 1,
        devFeeRateBPS: 0.15 * 1e4,
        minProfitDuration: 30, // 30 second
        maxPosition: 5
      })
    );

    // Assume
    uint256 lastIncrease = block.timestamp;
    uint256 afterMinProfitDuration = lastIncrease + 30;

    // price up -> profit
    (bool isProfit, uint256 delta) = calculator.getDelta(size, isLong, nextPrice, avgPriceE30, lastIncrease);
    assertEq(isProfit, true);
    assertEq(delta, 0);

    vm.warp(afterMinProfitDuration);

    // price up -> profit
    (isProfit, delta) = calculator.getDelta(size, isLong, nextPrice, avgPriceE30, lastIncrease);
    assertEq(isProfit, true);
    assertEq(delta, 500000000000000000000000000000000);
  }
}
