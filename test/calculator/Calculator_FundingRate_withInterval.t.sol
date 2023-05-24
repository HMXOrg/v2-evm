// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract Calculator_FundingRate is Calculator_Base {
  struct FundingRate {
    int256 accumFundingLong;
    int256 accumFundingShort;
    int256 accumFundingRate;
    int256 nextFundingRateLong;
    int256 nextFundingRateShort;
    int256 fundingFeeLong;
    int256 fundingFeeShort;
  }

  function setUp() public virtual override {
    super.setUp();

    // Set market config
    // maxFundingRate = 0.04%
    // maxSkewScaleUSD = 3m USD
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: "BTC",
        maxLongPositionSize: 10_000_000 * 1e30,
        maxShortPositionSize: 10_000_000 * 1e30,
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        minLeverageBPS: 1 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: false,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0.0004 * 1e18, maxSkewScaleUSD: 3_000_000 * 1e30 })
      })
    );

    // Simulate ALICE contains 1 opening LONG position
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0,
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0
      })
    );

    // Simulate BOB contains 1 opening SHORT position
    mockPerpStorage.setPositionBySubAccount(
      BOB,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0,
        positionSizeE30: -50_000 * 1e30,
        avgEntryPriceE30: 25_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0
      })
    );
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
  // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
  // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
  // |   1 |    0 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00013333 |      -0.00013333 |
  // |   2 |    5 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00066667 |          -0.0008 |
  // |   3 |   10 |       1000000 |        1000000 |               0 |                 0 |                        0 |          -0.0008 |
  // |   4 |   15 |       1000000 |        1000000 |               0 |                 0 |                        0 |          -0.0008 |
  // |   5 |   20 |       1000000 |        3000000 |        -2000000 |        0.00026667 |               0.00133333 |       0.00053333 |
  // |   6 |   25 |       1000000 |        3000000 |        -2000000 |        0.00026667 |               0.00133333 |       0.00186667 |
  // |   7 |   30 |       1000000 |        3000000 |        -2000000 |        0.00026667 |               0.00133333 |           0.0032 |
  // |   8 |   35 |       2000000 |        3000000 |        -1000000 |        0.00013333 |               0.00066667 |       0.00386667 |
  // |   9 |   40 |       2500000 |        3000000 |         -500000 |        0.00006667 |               0.00033333 |           0.0042 |
  // |  10 |   45 |       2500000 |        3000000 |         -500000 |        0.00006667 |               0.00033333 |       0.00453333 |
  // |  11 |   50 |       6000000 |        3000000 |         3000000 |           -0.0004 |                   -0.002 |       0.00253333 |
  // |  12 |   55 |       6000000 |        3000000 |         3000000 |           -0.0004 |                   -0.002 |       0.00053333 |
  // |  13 |   60 |       6000000 |        3000000 |         3000000 |           -0.0004 |                   -0.002 |      -0.00146667 |
  // |  14 |   65 |       6000000 |        3000000 |         3000000 |           -0.0004 |                   -0.002 |      -0.00346667 |
  // |  15 |   70 |       6000000 |        3000000 |         3000000 |           -0.0004 |                   -0.002 |      -0.00546667 |
  // |  16 |   75 |       6000000 |        3000000 |         3000000 |           -0.0004 |                   -0.002 |      -0.00746667 |

  function testCorrectness_getFundingRateVelocity_withInterval() external {
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   1 |    0 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00013333 |      -0.00013333 |

    FundingRate memory vars;

    // Mock global market config as table above
    uint256 marketIndex = 0;

    uint256 longPositionSize = 2_000_000 * 1e30;

    uint256 shortPositionSize = 2_000_000 * 1e30;

    vars.accumFundingLong = 0;
    vars.accumFundingShort = 0;
    vars.accumFundingRate = 0;
    vars.nextFundingRateLong = 0;
    vars.nextFundingRateShort = 0;
    vars.fundingFeeLong = 0;
    vars.fundingFeeShort = 0;

    // Set WBTC 20,000
    mockOracle.setPrice(20_000 * 1e30);

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      vars.accumFundingLong,
      vars.accumFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      vars.accumFundingShort,
      vars.accumFundingRate
    );

    int256 nextFundingRate = calculator.getFundingRateVelocity(0);
    vars.accumFundingRate += nextFundingRate;

    if (longPositionSize > 0) {
      vars.fundingFeeLong = (vars.accumFundingRate * int(longPositionSize)) / 1e30;
    }
    if (shortPositionSize > 0) {
      vars.fundingFeeShort = (vars.accumFundingRate * -int(shortPositionSize)) / 1e30;
    }

    vars.accumFundingLong += vars.fundingFeeLong;
    vars.accumFundingShort += vars.fundingFeeShort;

    assertEq(vars.accumFundingRate, -133333333333333);
    assertEq(nextFundingRate, -133333333333333);
    assertEq(vars.fundingFeeLong, -266666666666666000000);
    assertEq(vars.fundingFeeShort, 133333333333333000000);

    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   1 |    0 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00013333 |      -0.00013333 |
    // |   2 |    5 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00066667 |          -0.0008 |

    vm.warp(5);
    {
      // Mock global market config as table above
      longPositionSize = 2_000_000 * 1e30;

      vars.accumFundingLong += vars.nextFundingRateLong; //start accrued funding rate

      shortPositionSize = 1_000_000 * 1e30;

      vars.accumFundingShort += vars.nextFundingRateShort; //start accrued funding rate

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        vars.accumFundingLong,
        vars.accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        vars.accumFundingShort,
        vars.accumFundingRate
      );

      nextFundingRate = calculator.getFundingRateVelocity(0);
      vars.accumFundingRate += nextFundingRate;

      if (longPositionSize > 0) {
        vars.fundingFeeLong = (vars.accumFundingRate * int(longPositionSize)) / 1e30;
      }
      if (shortPositionSize > 0) {
        vars.fundingFeeShort = (vars.accumFundingRate * -int(shortPositionSize)) / 1e30;
      }

      vars.accumFundingLong += vars.fundingFeeLong;
      vars.accumFundingShort += vars.fundingFeeShort;

      assertEq(nextFundingRate, -666666666666665);
      assertEq(vars.accumFundingRate, -799999999999998);
      assertEq(vars.fundingFeeLong, -1599999999999996000000);
      assertEq(vars.fundingFeeShort, 799999999999998000000);
    }

    vm.warp(5);
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   2 |    5 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00066667 |          -0.0008 |
    // |   3 |   10 |       1000000 |        1000000 |               0 |                 0 |                        0 |          -0.0008 |

    {
      // Mock global market config as table above
      longPositionSize = 1_000_000 * 1e30;

      vars.accumFundingLong += vars.nextFundingRateLong;

      shortPositionSize = 1_000_000 * 1e30;

      vars.accumFundingShort += vars.nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        vars.accumFundingLong,
        vars.accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        vars.accumFundingShort,
        vars.accumFundingRate
      );

      nextFundingRate = calculator.getFundingRateVelocity(0);
      vars.accumFundingRate += nextFundingRate;

      if (longPositionSize > 0) {
        vars.fundingFeeLong = (vars.accumFundingRate * int(longPositionSize)) / 1e30;
      }
      if (shortPositionSize > 0) {
        vars.fundingFeeShort = (vars.accumFundingRate * -int(shortPositionSize)) / 1e30;
      }

      vars.accumFundingLong += vars.fundingFeeLong;
      vars.accumFundingShort += vars.fundingFeeShort;

      assertEq(nextFundingRate, 0);
      assertEq(vars.accumFundingRate, -799999999999998); // -0.0008
      assertEq(vars.fundingFeeLong, -799999999999998000000);
      assertEq(vars.fundingFeeShort, 799999999999998000000);
    }

    vm.warp(5);
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   3 |   10 |       1000000 |        1000000 |               0 |                 0 |                        0 |          -0.0008 |
    // |   4 |   15 |       1000000 |        1000000 |               0 |                 0 |                        0 |          -0.0008 |

    {
      // Mock global market config as table above
      longPositionSize = 1_000_000 * 1e30;

      vars.accumFundingLong += vars.nextFundingRateLong;

      shortPositionSize = 1_000_000 * 1e30;

      vars.accumFundingShort += vars.nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        vars.accumFundingLong,
        vars.accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        vars.accumFundingShort,
        vars.accumFundingRate
      );

      nextFundingRate = calculator.getFundingRateVelocity(0);
      vars.accumFundingRate += nextFundingRate;

      if (longPositionSize > 0) {
        vars.fundingFeeLong = (vars.accumFundingRate * int(longPositionSize)) / 1e30;
      }
      if (shortPositionSize > 0) {
        vars.fundingFeeShort = (vars.accumFundingRate * -int(shortPositionSize)) / 1e30;
      }

      vars.accumFundingLong += vars.fundingFeeLong;
      vars.accumFundingShort += vars.fundingFeeShort;

      assertEq(nextFundingRate, 0);
      assertEq(vars.accumFundingRate, -799999999999998); // -0.0008
      assertEq(vars.fundingFeeLong, -799999999999998000000);
      assertEq(vars.fundingFeeShort, 799999999999998000000);
    }

    vm.warp(5);
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   4 |   15 |       1000000 |        1000000 |               0 |                 0 |                        0 |          -0.0008 |
    // |   5 |   20 |       1000000 |        3000000 |        -2000000 |        0.00026667 |               0.00133333 |       0.00053333 |

    {
      // Mock global market config as table above
      longPositionSize = 1_000_000 * 1e30;

      vars.accumFundingLong += vars.nextFundingRateLong;

      shortPositionSize = 3_000_000 * 1e30;

      vars.accumFundingShort += vars.nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        vars.accumFundingLong,
        vars.accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        vars.accumFundingShort,
        vars.accumFundingRate
      );

      nextFundingRate = calculator.getFundingRateVelocity(0);
      vars.accumFundingRate += nextFundingRate;

      if (longPositionSize > 0) {
        vars.fundingFeeLong = (vars.accumFundingRate * int(longPositionSize)) / 1e30;
      }
      if (shortPositionSize > 0) {
        vars.fundingFeeShort = (vars.accumFundingRate * -int(shortPositionSize)) / 1e30;
      }

      vars.accumFundingLong += vars.fundingFeeLong;
      vars.accumFundingShort += vars.fundingFeeShort;

      assertEq(nextFundingRate, 1333333333333330); //0.00133333
      assertEq(vars.accumFundingRate, 533333333333332); //0.00053333
      assertEq(vars.fundingFeeLong, 533333333333332000000);
      assertEq(vars.fundingFeeShort, -1599999999999996000000);
    }

    vm.warp(5);

    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   5 |   20 |       1000000 |        3000000 |        -2000000 |        0.00026667 |               0.00133333 |       0.00053333 |
    // |   6 |   25 |       1000000 |        3000000 |        -2000000 |        0.00026667 |               0.00133333 |       0.00186667 |

    // Mock global market config as table above
    {
      longPositionSize = 1_000_000 * 1e30;
      vars.accumFundingLong += vars.nextFundingRateLong;

      shortPositionSize = 3_000_000 * 1e30;
      vars.accumFundingShort += vars.nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        vars.accumFundingLong,
        vars.accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        vars.accumFundingShort,
        vars.accumFundingRate
      );

      nextFundingRate = calculator.getFundingRateVelocity(0);
      vars.accumFundingRate += nextFundingRate;

      if (longPositionSize > 0) {
        vars.fundingFeeLong = (vars.accumFundingRate * int(longPositionSize)) / 1e30;
      }
      if (shortPositionSize > 0) {
        vars.fundingFeeShort = (vars.accumFundingRate * -int(shortPositionSize)) / 1e30;
      }

      vars.accumFundingLong += vars.fundingFeeLong;
      vars.accumFundingShort += vars.fundingFeeShort;

      assertEq(nextFundingRate, 1333333333333330); //0.00133333
      assertEq(vars.accumFundingRate, 1866666666666662); //0.00186667
      assertEq(vars.fundingFeeLong, 1866666666666662000000);
      assertEq(vars.fundingFeeShort, -5599999999999986000000);
    }
  }
}
