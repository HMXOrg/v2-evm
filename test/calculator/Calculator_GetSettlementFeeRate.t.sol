// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_BaseWithStorage, IPerpStorage } from "./Calculator_BaseWithStorage.t.sol";

// What is this test DONE
// - correctness
//   - liquidity delta usd is 0
//   - next diff > current diff (pool better)
//   - next diff < current diff (pool worst)

contract Calculator_GetSettlementFeeRate is Calculator_BaseWithStorage {
  function setUp() public virtual override {
    super.setUp();

    configStorage.setPLPTotalTokenWeight(1e18);
  }

  function testCorrectness_WhenGetSettlementFeeRateWithZeroDelta() external {
    uint256 _rate = calculator.getSettlementFeeRate(address(weth), 0, 0, 0);
    assertEq(_rate, 0);
  }

  function testCorrectness_WhenGetSettlementFeeRateAndMakePoolBetterThenNoFee() external {
    // usd debt
    // vaultStorage.addPLPLiquidityUSDE30(address(weth), 3000 * 1e30);
    vaultStorage.addPLPLiquidity(address(weth), 3000 ether);
    vaultStorage.addPLPLiquidity(address(dai), 7000 ether);

    // liquidity config
    // tax fee rate = 0.5%
    // total weight = 100%
    // plp WETH pool weigh = 20%
    uint256 _rate = calculator.getSettlementFeeRate(address(weth), 1200 * 1e30, 0, 0);

    // calculation
    // usd debt = 3000
    // total usd debt = 10000
    // next value = 3000 - 1200 = 1800
    // target value = 10000 * 20 / 100 = 2000
    // next target diff = | 1800 - 2000 | = 200
    // current target diff = | 3000 - 2000 | = 1000
    // then next target diff < current target diff then settlement fee rate should be 0
    assertEq(_rate, 0);
  }

  function testCorrectness_WhenGetSettlementFeeRateAndMakePoolWorst() external {
    // usd debt
    vaultStorage.addPLPLiquidity(address(dai), 1_000 ether);
    vaultStorage.addPLPLiquidity(address(weth), 9_000 ether);

    // liquidity config
    // tax fee rate = 0.5%
    // total weight = 100%
    // plp DAI pool weigh = 10%
    uint256 _rate = calculator.getSettlementFeeRate(address(dai), 200 * 1e30, 0, 0);

    // calculation
    // usd debt = 1000
    // total usd debt = 10000
    // next value = 1000 - 200 = 1800
    // target value = 10000 * 10 / 100 = 1000
    // next target diff = | 1800 - 2000 | = 200
    // current target diff = | 1000 - 2000 | = 0
    // then next target diff > current target diff
    // then settlement fee rate = (next target diff + current target diff / 2) * tax fee rate / target value
    //      = ((200 + 0) / 2) * 0.5 / 1000 = 0.05%
    assertEq(_rate, 5e14); // 100% = 1 * 10^18, 0.05% = 5 * 10^14
  }
}
