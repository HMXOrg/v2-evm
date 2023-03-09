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
    // maxFundingRateBPS = 0.04%
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
        fundingRate: IConfigStorage.FundingRate({ maxFundingRateBPS: 0.0004 * 1e4, maxSkewScaleUSD: 3_000_000 * 1e30 })
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

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
  // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // | 1   | 0              | 2,000,000.00 | 1,000,000.00 | 1,000,000.00   | -0.013333%        | -0.013333%              | 0               | 0               | 0                  | 0                   |
  // | 2   | 5              | 2,000,000.00 | 1,000,000.00 | 1,000,000.00   | -0.026667%        | -0.133333%              | -266.6666667    | 133.3333333     | -266.6666667       | 133.3333333         |
  // | 3   | 10             | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%        | -0.133333%              | -2666.666667    | 1333.333333     | -2933.333333       | 1466.666667         |
  // | 4   | 15             | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%        | -0.133333%              | -1333.333333    | 1333.333333     | -4266.666667       | 2800                |
  // | 5   | 20             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.000000%         | 0.000000%               | -1333.333333    | 1333.333333     | -5600              | 4133.333333         |
  // | 6   | 25             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.026667%         | 0.133333%               | 0               | 0               | -5600              | 4133.333333         |
  // | 7   | 30             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.053333%         | 0.266667%               | 1333.333333     | -4000           | -4266.666667       | 133.3333333         |
  // | 8   | 35             | 2,000,000.00 | 3,000,000.00 | -1,000,000.00  | 0.066667%         | 0.333333%               | 2666.666667     | -8000           | -1600              | -7866.666667        |
  // | 9   | 40             | 2,500,000.00 | 3,000,000.00 | -500,000.00    | 0.073333%         | 0.366667%               | 6666.666667     | -10000          | 5066.666667        | -17866.66667        |
  // | 10  | 45             | 2,500,000.00 | 3,000,000.00 | -500,000.00    | 0.080000%         | 0.400000%               | 9166.666667     | -11000          | 14233.33333        | -28866.66667        |
  // | 11  | 50             | 6,000,000.00 | 3,000,000.00 | 3,000,000.00   | 0.040000%         | 0.200000%               | 10000           | -12000          | 24233.33333        | -40866.66667        |
  // | 12  | 55             | 6,000,000.00 | 3,000,000.00 | 3,000,000.00   | 0.000000%         | 0.000000%               | 12000           | -6000           | 36233.33333        | -46866.66667        |
  // | 13  | 60             | 6,000,000.00 | 3,000,000.00 | 3,000,000.00   | -0.040000%        | -0.200000%              | 0               | 0               | 36233.33333        | -46866.66667        |
  // | 14  | 65             | 6,000,000.00 | 3,000,000.00 | 3,000,000.00   | -0.080000%        | -0.400000%              | -12000          | 6000            | 24233.33333        | -40866.66667        |
  // | 15  | 70             | 6,000,000.00 | 3,000,000.00 | 3,000,000.00   | -0.120000%        | -0.600000%              | -24000          | 12000           | 233.3333333        | -28866.66667        |
  // | 16  | 75             | 6,000,000.00 | 3,000,000.00 | 3,000,000.00   | -0.160000%        | -0.800000%              | -36000          | 18000           | -35766.66667       | -10866.66667        |

  function testCorrectness_getNextFundingRate_withInterval() external {
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 1   | 0              | 2,000,000.00 | 1,000,000.00 | 1,000,000.00   | -0.013333%        | -0.013333%              | 0               | 0               | 0                  | 0                   |
    // | 2   | 5              | 2,000,000.00 | 1,000,000.00 | 1,000,000.00   | -0.026667%        | -0.133333%              | -266.6666667    | 133.3333333     | -266.6666667       | 133.3333333         |

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

    int256 currentFundingRate = 0;

    // Set WBTC 20,000
    mockOracle.setPrice(20_000 * 1e30);

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      currentFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      currentFundingRate
    );

    (int256 newfundingRate, int256 nextfundingRateLong, int256 nextfundingRateShort) = calculator.getNextFundingRate(
      0,
      0
    );
    currentFundingRate = newfundingRate; // -0.013333%
    assertEq(newfundingRate, -133333333333333); // -0.013333%

    assertEq(nextfundingRateLong, -266666666666666000000); // -266.6666667
    assertEq(nextfundingRateShort, 133333333333333000000); // 133.3333333

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, 0);
    assertEq(accumFundingRateShort, 0);

    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 2   | 5              | 2,000,000.00 | 1,000,000.00 | 1,000,000.00   | -0.026667%        | -0.133333%              | -266.6666667    | 133.3333333     | -266.6666667       | 133.3333333         |
    // | 3   | 10             | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%        | -0.133333%              | -2666.666667    | 1333.333333     | -2933.333333       | 1466.666667         |

    vm.warp(5); // make elapsed intervals to 5

    // Mock global market config as table above
    longPositionSize = 2_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 100 * 10 ** 8;
    accumFundingRateLong += nextfundingRateLong; //start accured funding rate

    shortPositionSize = 1_000_000 * 1e30;
    shortAvgPrice = 20_000 * 1e30;
    shortOpenInterest = 50 * 10 ** 8;
    accumFundingRateShort += nextfundingRateShort; //start accured funding rate

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      currentFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      currentFundingRate
    );

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = calculator.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // -0.026667%
    assertEq(newfundingRate, -266666666666666); // -0.026667%

    assertEq(nextfundingRateLong, -2666666666666660000000); // -2666.666667
    assertEq(nextfundingRateShort, 1333333333333330000000); // 1333.333333

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -266666666666666000000); // -266.6666667
    assertEq(accumFundingRateShort, 133333333333333000000); // 133.3333333

    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 3   | 10             | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%        | -0.133333%              | -2666.666667    | 1333.333333     | -2933.333333       | 1466.666667         |
    // | 4   | 15             | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%        | -0.133333%              | -1333.333333    | 1333.333333     | -4266.666667       | 2800                |

    vm.warp(5); // make elapsed intervals to 5

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 50 * 10 ** 8;
    accumFundingRateLong += nextfundingRateLong;

    shortPositionSize = 1_000_000 * 1e30;
    shortAvgPrice = 20_000 * 1e30;
    shortOpenInterest = 50 * 10 ** 8;
    accumFundingRateShort += nextfundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      currentFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      currentFundingRate
    );

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = calculator.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // -0.026667%
    assertEq(newfundingRate, -266666666666666); // -0.026667%

    assertEq(nextfundingRateLong, -1333333333333330000000); // -1333.333333
    assertEq(nextfundingRateShort, 1333333333333330000000); // 1333.333333

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -2933333333333326000000); // -2933.333333
    assertEq(accumFundingRateShort, 1466666666666663000000); // 1466.666667

    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 4   | 15             | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%        | -0.133333%              | -1333.333333    | 1333.333333     | -4266.666667       | 2800                |
    // | 5   | 20             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.000000%         | 0.000000%               | -1333.333333    | 1333.333333     | -5600              | 4133.333333         |

    vm.warp(5); // make elapsed intervals to 5

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 50 * 10 ** 8;
    accumFundingRateLong += nextfundingRateLong;

    shortPositionSize = 1_000_000 * 1e30;
    shortAvgPrice = 20_000 * 1e30;
    shortOpenInterest = 50 * 10 ** 8;
    accumFundingRateShort += nextfundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      currentFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      currentFundingRate
    );

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = calculator.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // -0.026667%
    assertEq(newfundingRate, -266666666666666); // -0.026667%

    assertEq(nextfundingRateLong, -1333333333333330000000); // -1333.333333
    assertEq(nextfundingRateShort, 1333333333333330000000); // 1333.333333

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -4266666666666656000000); // -4266.666667
    assertEq(accumFundingRateShort, 2799999999999993000000); // 2800

    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 5   | 20             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.000000%         | 0.000000%               | -1333.333333    | 1333.333333     | -5600              | 4133.333333         |
    // | 6   | 25             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.026667%         | 0.133333%               | 0               | 0               | -5600              | 4133.333333         |

    vm.warp(5); // make elapsed intervals to 5

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 50 * 10 ** 8;
    accumFundingRateLong += nextfundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;
    shortAvgPrice = 20_000 * 1e30;
    shortOpenInterest = 150 * 10 ** 8;
    accumFundingRateShort += nextfundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      currentFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      currentFundingRate
    );

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = calculator.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0%
    assertEq(newfundingRate, 0); // 0%

    assertEq(nextfundingRateLong, 0); // 0%
    assertEq(nextfundingRateShort, 0); // 0%

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -5599999999999986000000); // -5600
    assertEq(accumFundingRateShort, 4133333333333323000000); // 4133.333333

    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 6   | 25             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.026667%         | 0.133333%               | 0               | 0               | -5600              | 4133.333333         |
    // | 7   | 30             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.053333%         | 0.266667%               | 1333.333333     | -4000           | -4266.666667       | 133.3333333         |

    vm.warp(5); // make elapsed intervals to 5

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 50 * 10 ** 8;
    accumFundingRateLong += nextfundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;
    shortAvgPrice = 20_000 * 1e30;
    shortOpenInterest = 150 * 10 ** 8;
    accumFundingRateShort += nextfundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      currentFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      currentFundingRate
    );

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = calculator.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate;
    assertEq(newfundingRate, 266666666666666); // 0.266667%

    assertEq(nextfundingRateLong, 1333333333333330000000); // 1333.333333
    assertEq(nextfundingRateShort, -3999999999999990000000); // -4000

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -5599999999999986000000); // -5600
    assertEq(accumFundingRateShort, 4133333333333323000000); // 4133.333333

    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row | elapsedInterval | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | CurrentFundingRateXTime | LongFundingFee | ShortFundingFee | LongFundingAccrued | ShortFundingAccrued |
    // ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 7   | 30             | 1,000,000.00 | 3,000,000.00 | -2,000,000.00  | 0.053333%         | 0.266667%               | 1333.333333     | -4000           | -4266.666667       | 133.3333333         |
    // | 8   | 35             | 2,000,000.00 | 3,000,000.00 | -1,000,000.00  | 0.066667%         | 0.333333%               | 2666.666667     | -8000           | -1600              | -7866.666667        |

    vm.warp(5); // make elapsed intervals to 5

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 50 * 10 ** 8;
    accumFundingRateLong += nextfundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;
    shortAvgPrice = 20_000 * 1e30;
    shortOpenInterest = 150 * 10 ** 8;
    accumFundingRateShort += nextfundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(
      marketIndex,
      longPositionSize,
      longAvgPrice,
      longOpenInterest,
      accumFundingRateLong,
      currentFundingRate
    );
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      shortAvgPrice,
      shortOpenInterest,
      accumFundingRateShort,
      currentFundingRate
    );

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = calculator.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate;
    assertEq(newfundingRate, 533333333333332); // 0.053333%

    assertEq(nextfundingRateLong, 2666666666666660000000); // 2666.666667
    assertEq(nextfundingRateShort, -7999999999999980000000); // -8000

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -4266666666666656000000); // -4266.666667
    assertEq(accumFundingRateShort, 133333333333333000000); // 133.3333333
  }
}
