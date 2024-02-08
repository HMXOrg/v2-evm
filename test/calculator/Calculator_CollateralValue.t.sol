// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";

// What is this test DONE
// - success
//   - Try get collateral values with NO depositing collateral tokens on trader's sub account
//   - Try get collateral values with CONTAIN depositing collateral tokens on trader's sub account

contract Calculator_IMR is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // Try get collateral values with no depositing collateral tokens on trader's sub account
  function testCorrectness_getCollateralValue_noDepositCollateral() external {
    // ALICE never deposit collateral, so collateral value must return 0
    assertEq(calculator.getCollateralValue(ALICE, 0, 0), 0);
  }

  // Try get collateral values with contain depositing collateral tokens on trader's sub account
  function testCorrectness_getCollateralValue_withDepositCollateral() external {
    // First, Assume ALICE only has one collateral token, ybETH
    mockVaultStorage.setTraderTokens(ALICE, address(ybeth));
    mockVaultStorage.setTraderBalance(ALICE, address(ybeth), 10 ether);

    // ybETH CollateralValue = amount * price * collateralFactor
    // ybETH CollateralValue = 10 ether * 1E30 * 0.8 = 8 ether
    assertEq(calculator.getCollateralValue(ALICE, 0, 0), 8 * 1e30);

    // Second, Assume ALICE deposit more new collateral, WBTC
    mockVaultStorage.setTraderTokens(ALICE, address(wbtc));
    mockVaultStorage.setTraderBalance(ALICE, address(wbtc), 10 * 1e8);

    // WBTC CollateralValue = (amount * price * collateralFactor)
    // WBTC CollateralValue = 10 ether * 1E30 * 0.9 = 9 ether
    // Total CollateralValue = WETH CollateralValue + WBTC CollateralValue
    // Total CollateralValue = 8 ether + 9 ether = 17 ether
    assertEq(calculator.getCollateralValue(ALICE, 0, 0), 17 * 1e30);
  }
}
