// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract Calculator_FundingRate is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();

    mockOracle.setExponent(-8);

    // Set market config
    // maxFundingRate = 0.04%
    // maxSkewScaleUSD = 3m USD
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: "BTC",
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        minLeverageBPS: 1 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: false,
        active: true,
        openInterest: IConfigStorage.OpenInterest({
          longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
          shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
        }),
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
        realizedPnl: 0,
        openInterest: 5 * 10 ** 8
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
        realizedPnl: 0,
        openInterest: 2 * 10 ** 8
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
  function testCorrectness_getNextFundingRate_withInterval() external {
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   1 |    0 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00013333 |      -0.00013333 |

    // Mock global market config as table above
    uint256 marketIndex = 0;

    uint256 longPositionSize = 2_000_000 * 1e30;
    uint256 longAvgPrice = 20_000 * 1e30;
    uint256 longOpenInterest = 100 * 10 ** 8;
    int256 accumFundingRateLong = 0;

    uint256 shortPositionSize = 1_000_000 * 1e30;
    uint256 shortAvgPrice = 20_000 * 1e30;
    uint256 shortOpenInterest = 50 * 10 ** 8;
    int256 accumFundingRateShort = 0;

    int256 accumFundingRate = 0;

    // Set WBTC 20,000
    mockOracle.setPrice(20_000 * 1e30);

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      accumFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      accumFundingRate
    );

    (int256 nextFundingRate, int256 nextFundingRateLong, int256 nextFundingRateShort) = calculator.getNextFundingRate(
      0
    );
    accumFundingRate += nextFundingRate;
    assertEq(accumFundingRate, -133333333333333);
    assertEq(nextFundingRate, -133333333333333);

    // @todo come back to fix this after dealing with excessive funding fee to plp
    // assertEq(nextFundingRateLong, -266666666666666000000); // -266.6666667
    // assertEq(nextFundingRateShort, 133333333333333000000); // 133.3333333

    // (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    // assertEq(accumFundingRateLong, 0);
    // assertEq(accumFundingRateShort, 0);

    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // | Row | Time | Long Size USD | Short Size USD | Market Skew USD | Next Funding Rate | Next Funding Rate x Time | Acm Funding Rate |
    // |-----|------|---------------|----------------|-----------------|-------------------|--------------------------|------------------|
    // |   1 |    0 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00013333 |      -0.00013333 |
    // |   2 |    5 |       2000000 |        1000000 |         1000000 |       -0.00013333 |              -0.00066667 |          -0.0008 |

    vm.warp(5);
    {
      // Mock global market config as table above
      longPositionSize = 2_000_000 * 1e30;
      longAvgPrice = 20_000 * 1e30;
      longOpenInterest = 100 * 10 ** 8;
      accumFundingRateLong += nextFundingRateLong; //start accrued funding rate

      shortPositionSize = 1_000_000 * 1e30;
      shortAvgPrice = 20_000 * 1e30;
      shortOpenInterest = 50 * 10 ** 8;
      accumFundingRateShort += nextFundingRateShort; //start accrued funding rate

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        longAvgPrice,
        longOpenInterest,
        accumFundingRateLong,
        accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        shortAvgPrice,
        shortOpenInterest,
        accumFundingRateShort,
        accumFundingRate
      );

      (nextFundingRate, nextFundingRateLong, nextFundingRateShort) = calculator.getNextFundingRate(0);
      accumFundingRate += nextFundingRate;
      assertEq(nextFundingRate, -666666666666665);
      assertEq(accumFundingRate, -799999999999998);

      // @todo come back to fix this after dealing with excessive funding fee to plp
      // assertEq(nextFundingRateLong, -2666666666666660000000); // -2666.666667
      // assertEq(nextFundingRateShort, 1333333333333330000000); // 1333.333333

      // (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
      // assertEq(accumFundingRateLong, -266666666666666000000); // -266.6666667
      // assertEq(accumFundingRateShort, 133333333333333000000); // 133.3333333
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
      longAvgPrice = 20_000 * 1e30;
      longOpenInterest = 50 * 10 ** 8;
      accumFundingRateLong += nextFundingRateLong;

      shortPositionSize = 1_000_000 * 1e30;
      shortAvgPrice = 20_000 * 1e30;
      shortOpenInterest = 50 * 10 ** 8;
      accumFundingRateShort += nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        longAvgPrice,
        longOpenInterest,
        accumFundingRateLong,
        accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        shortAvgPrice,
        shortOpenInterest,
        accumFundingRateShort,
        accumFundingRate
      );

      (nextFundingRate, nextFundingRateLong, nextFundingRateShort) = calculator.getNextFundingRate(0);
      accumFundingRate += nextFundingRate;
      assertEq(nextFundingRate, 0);
      assertEq(accumFundingRate, -799999999999998); // -0.0008

      // @todo come back to fix this after dealing with excessive funding fee to plp
      // assertEq(nextFundingRateLong, -1333333333333330000000); // -1333.333333
      // assertEq(nextFundingRateShort, 1333333333333330000000); // 1333.333333

      // (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
      // assertEq(accumFundingRateLong, -2933333333333326000000); // -2933.333333
      // assertEq(accumFundingRateShort, 1466666666666663000000); // 1466.666667
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
      longAvgPrice = 20_000 * 1e30;
      longOpenInterest = 50 * 10 ** 8;
      accumFundingRateLong += nextFundingRateLong;

      shortPositionSize = 1_000_000 * 1e30;
      shortAvgPrice = 20_000 * 1e30;
      shortOpenInterest = 50 * 10 ** 8;
      accumFundingRateShort += nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        longAvgPrice,
        longOpenInterest,
        accumFundingRateLong,
        accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        shortAvgPrice,
        shortOpenInterest,
        accumFundingRateShort,
        accumFundingRate
      );

      (nextFundingRate, nextFundingRateLong, nextFundingRateShort) = calculator.getNextFundingRate(0);
      accumFundingRate += nextFundingRate;
      assertEq(nextFundingRate, 0);
      assertEq(accumFundingRate, -799999999999998);

      // @todo come back to fix this after dealing with excessive funding fee to plp
      // assertEq(nextFundingRateLong, -1333333333333330000000); // -1333.333333
      // assertEq(nextFundingRateShort, 1333333333333330000000); // 1333.333333

      // (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
      // assertEq(accumFundingRateLong, -4266666666666656000000); // -4266.666667
      // assertEq(accumFundingRateShort, 2799999999999993000000); // 2800
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
      longAvgPrice = 20_000 * 1e30;
      longOpenInterest = 50 * 10 ** 8;
      accumFundingRateLong += nextFundingRateLong;

      shortPositionSize = 3_000_000 * 1e30;
      shortAvgPrice = 20_000 * 1e30;
      shortOpenInterest = 150 * 10 ** 8;
      accumFundingRateShort += nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        longAvgPrice,
        longOpenInterest,
        accumFundingRateLong,
        accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        shortAvgPrice,
        shortOpenInterest,
        accumFundingRateShort,
        accumFundingRate
      );

      (nextFundingRate, nextFundingRateLong, nextFundingRateShort) = calculator.getNextFundingRate(0);
      accumFundingRate += nextFundingRate;
      assertEq(nextFundingRate, 1333333333333330); //0.00133333
      assertEq(accumFundingRate, 533333333333332); //0.00053333

      // @todo come back to fix this after dealing with excessive funding fee to plp
      // assertEq(nextFundingRateLong, 0);
      // assertEq(nextFundingRateShort, 0);

      // (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
      // assertEq(accumFundingRateLong, -5599999999999986000000); // -5600
      // assertEq(accumFundingRateShort, 4133333333333323000000); // 4133.333333
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
      longAvgPrice = 20_000 * 1e30;
      longOpenInterest = 50 * 10 ** 8;
      accumFundingRateLong += nextFundingRateLong;

      shortPositionSize = 3_000_000 * 1e30;
      shortAvgPrice = 20_000 * 1e30;
      shortOpenInterest = 150 * 10 ** 8;
      accumFundingRateShort += nextFundingRateShort;

      mockPerpStorage.updateGlobalLongMarketById(
        marketIndex,
        longPositionSize,
        longAvgPrice,
        longOpenInterest,
        accumFundingRateLong,
        accumFundingRate
      );
      mockPerpStorage.updateGlobalShortMarketById(
        marketIndex,
        shortPositionSize,
        shortAvgPrice,
        shortOpenInterest,
        accumFundingRateShort,
        accumFundingRate
      );

      (nextFundingRate, nextFundingRateLong, nextFundingRateShort) = calculator.getNextFundingRate(0);
      accumFundingRate += nextFundingRate;
      assertEq(nextFundingRate, 1333333333333330); //0.00133333
      assertEq(accumFundingRate, 1866666666666662); //0.00186667

      // // @todo come back to fix this after dealing with excessive funding fee to plp
      // assertEq(nextFundingRateLong, 1333333333333330000000); // 1333.333333
      // assertEq(nextFundingRateShort, -3999999999999990000000); // -4000

      // (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
      // assertEq(accumFundingRateLong, -5599999999999986000000); // -5600
      // assertEq(accumFundingRateShort, 4133333333333323000000); // 4133.333333
    }
  }
}
