// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";
import { IPerpStorage } from "../../src/storages/interfaces/IPerpStorage.sol";

// What is this test DONE
// - success
//   - Try get Equity with no opening position on trader's sub account
//   - Try get Equity with only collateral deposited on trader's sub account
//   - Try get Equity with only position opening on trader's sub account [** In real life this should not happend]
//   - Try get Equity with collateral depositing and position opening with loss on trader's sub account

// What is this test not covered
//   - Price Stale checking from Oracle
//   - Borrowing Fee
//   - Funding Fee
//   - Realized PnL

contract Calculator_Equity is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // Try get Equity with no opening position on trader's sub account
  function testCorrectness_getEquity_noPosition() external {
    // CAROL not has any opening position, so unrealized PNL must return 0
    assertEq(calculator.getEquity(CAROL, 0, 0), 0);
  }

  // Try get Equity with only collateral deposited on trader's sub account
  function testCorrectness_getEquity_onlyCollateralToken() external {
    // First, Assume ALICE only has one collateral token, WETH
    mockVaultStorage.setTraderTokens(ALICE, address(weth));
    mockVaultStorage.setTraderBalance(ALICE, address(weth), 10 ether);

    // Set WBTC, WETH Price to 1,000
    mockOracle.setPrice(1_000 * 1e30);

    // WETH CollateralValue = amount * price * collateralFactor
    // WETH CollateralValue = 10 * 1_000 * 0.8 = 12_000
    assertEq(calculator.getEquity(ALICE, 0, 0), 8_000 * 1e30);

    // Senond, Assume ALICE deposit more new collateral, WBTC
    mockVaultStorage.setTraderTokens(ALICE, address(wbtc));
    mockVaultStorage.setTraderBalance(ALICE, address(wbtc), 5 * 1e8);

    // WBTC CollateralValue = (amount * price * collateralFactor)
    // WBTC CollateralValue = 5 * 1_000 * 0.9 = 4_500
    // Total CollateralValue = WETH CollateralValue + WBTC CollateralValue
    // Total CollateralValue = 8_000 + 4_500 = 12_500
    assertEq(calculator.getEquity(ALICE, 0, 0), 12_500 * 1e30);
  }

  // Try get Equity with only position opening with profit on trader's sub account [** In real life this should not happend]
  function testCorrectness_getEquity_onlyUnrealizedPnl_withProfit() external {
    // Simulate ALICE opening LONG position with profit
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 1_600 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Mock WETH Price to 2,000
    mockOracle.setPrice(2_000 * 1e30);
    configStorage.setPnlFactor(0.8 * 1e4);

    // Calculate unrealized pnl from ALICE's position
    // UnrealizedPnl = ABS(positionSize - priceDelta)/avgEntryPrice
    // If Profit then UnrealizedPnl = UnrealizedPnl * pnlFactor
    // UnrealizedPnl = (100,000 * (2,000 - 1,600))/1,600 = 25,000 in Profit
    // UnrealizedPnl = 25,000 * 0.8 = 20,000

    assertEq(calculator.getEquity(ALICE, 0, 0), 20_000 * 1e30);
  }

  // Try get Equity with collateral depositing and position opening with loss on trader's sub account
  function testCorrectness_getEquity_unrealizedPnl_withLoss() external {
    // First, Assume ALICE only has one collateral token, WETH
    mockVaultStorage.setTraderTokens(ALICE, address(weth));
    mockVaultStorage.setTraderBalance(ALICE, address(weth), 50 ether);

    // Mock WETH Price to 1,400
    mockOracle.setPrice(1_400 * 1e30);
    configStorage.setPnlFactor(0.8 * 1e4);

    // WETH CollateralValue = amount * price * collateralFactor
    // WETH CollateralValue = 50 * 1_400 * 0.8 = 56_000
    assertEq(calculator.getEquity(ALICE, 0, 0), 56_000 * 1e30);

    // Simulate ALICE opening LONG position with loss
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 1_600 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Calculate unrealized pnl from ALICE's position
    // UnrealizedPnl = ABS(positionSize - priceDelta)/avgEntryPrice
    // If Profit then UnrealizedPnl = UnrealizedPnl * pnlFactor
    // UnrealizedPnl = (100_000 * (1_400 - 1_600))/1_600 = -12_500

    // Equity = Collateral value + UnrealizedPnl
    // Equity = 56_000 + (-12_500) = 43_500
    assertEq(calculator.getEquity(ALICE, 0, 0), 43_500 * 1e30);
  }
}
