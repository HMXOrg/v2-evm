// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { Calculator_Base } from "./Calculator_Base.t.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract Calculator_FundingRate is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();

    // Set market config
    // maxFundingRate = 0.04%
    // maxSkewScaleUSD = 3m USD
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: wbtcAssetId,
        maxLongPositionSize: 10_000_000 * 1e30,
        maxShortPositionSize: 10_000_000 * 1e30,
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: false,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0.0004 * 1e18, maxSkewScaleUSD: 3_000_000 * 1e30 }),
        isAdaptiveFeeEnabled: false
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
        lastFundingAccrued: 0,
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
        lastFundingAccrued: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0
      })
    );
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // --------------------------------------------------------------------------------------------------------------------------------------------------------
  // | Row  | LongSizeUSD  | ShortSizeUSD | MarketSkewUSD  | CurrentFundingRate | LongFundingFee | ShortFundingFee | LongFundingAccrued| ShortFundingAccrued |
  // --------------------------------------------------------------------------------------------------------------------------------------------------------
  // | 1    | 2,000,000.00 | 1,000,000.00 | 1,000,000.00   | -0.013333%         | 0              | 0               | 0                 | 0                  |
  // | 2    | 2,000,000.00 | 1,000,000.00 | 1,000,000.00   | -0.026667%         | -266.6666667   | 133.3333333     | -266.6666667      | 133.3333333        |
  // | 3    | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%         | -533.3333333   | 266.6666667     | -800.0000000      | 400.0000000        |
  // | 4    | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.026667%         | -266.6666667   | 266.6666667     | -1,066.6666667    | 666.6666667        |
  // | 5    | 1,000,000.00 | 3,000,000.00 |-2,000,000.00   | 0.000000%          | -266.6666667   | 266.6666667     | -1,333.3333333    | 933.3333333        |
  // | 6    | 1,000,000.00 | 3,000,000.00 |-2,000,000.00   | 0.026667%          | 0              | 0               | -1,333.3333333    | 933.3333333        |
  // | 7    | 1,000,000.00 | 3,000,000.00 |-2,000,000.00   | 0.053333%          | 266.6666667    |-800.0000000     |-1,066.6666667     | 133.3333333        |
  // | 8    | 2,000,000.00 | 3,000,000.00 |-1,000,000.00   | 0.066667%          | 533.3333333    |-1,600.0000000   |-533.3333333       |-1,466.6666667      |
  // | 9    | 2,500,000.00 | 3,000,000.00 |-500,000.00     | 0.073333%          | 1,333.3333333  |-2,000.0000000   | 800.0000000       |-3,466.6666667      |
  // | 10   | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.040000%         | -400.0000000   | 200.0000000     | -400.0000000      | 200.0000000        |
  // | 11   | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.053333%         | -800.0000000   | 400.0000000     | -1,200.0000000    | 600.0000000        |
  // | 12   | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.066667%         | -1,200.0000000 | 600.0000000     | -2,400.0000000    | 1,200.0000000      |
  // | 13   | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.080000%         | -1,600.0000000 | 800.0000000     | -4,000.0000000    | 2,000.0000000      |
  // | 14   | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.093333%         | -2,000.0000000 | 1,000.0000000   | -6,000.0000000    | 3,000.0000000      |
  // | 15   | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.106667%         | -2,400.0000000 | 1,200.0000000   | -8,400.0000000    | 4,200.0000000      |
  // | 16   | 1,000,000.00 | 1,000,000.00 | 0.00           | -0.120000%         | -2,800.0000000 | 1,400.0000000   | -11,200.0000000   | 5,600.0000000      |
  // --------------------------------------------------------------------------------------------------------------------------------------------------------

  function testCorrectness_getFundingRateVelocity_noInterval() external {
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 1    | 2,000,000	  | 1,000,000    |	1,000,000    |	 0.013333%        |	0              |	0               |  0	                | 0
    // | 2    | 2,000,000	  | 1,000,000    |	1,000,000    |	 0.026667%        |	 266.6666667   | -133.3333333     |   266.6666667	      | -133.3333333

    // Mock global market config as table above
    uint256 marketIndex = 0;

    uint256 longPositionSize = 2_000_000 * 1e30;

    int256 accumFundingRateLong = 0;

    uint256 shortPositionSize = 1_000_000 * 1e30;

    int256 accumFundingRateShort = 0;

    int256 currentFundingRate = 0;
    int256 nextFundingRateLong = 0;
    int256 nextFundingRateShort = 0;

    // Set WBTC 20,000
    mockOracle.setPrice(20_000 * 1e30);

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    int256 nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate; // 0.013333%
    assertEq(nextFundingRate, 133333333333333); // 0.013333%
    assertEq(currentFundingRate, 133333333333333); // 0.013333%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 2    | 2,000,000	  | 1,000,000    |	1,000,000    |	 0.026667%        |	 266.6666667   |-133.3333333     |   266.6666667	      | -133.3333333
    // | 3    | 1,000,000	  | 1,000,000    |	0            |	 0.026667%        |	 533.3333333   |-266.6666667     |   800	              | -400

    // Mock global market config as table above
    longPositionSize = 2_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong; //start accrued funding rate

    shortPositionSize = 1_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort; //start accrued funding rate

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate; // 0.026667%
    assertEq(nextFundingRate, 133333333333333); // 0.013333%
    assertEq(currentFundingRate, 266666666666666); // 0.026667%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 3    | 1,000,000	  | 1,000,000    |	0            |	 0.026667%        |	 533.3333333   | -266.6666667     |   800	              | -400
    // | 4    | 1,000,000	  | 1,000,000    |	0            |	 0.026667%        |	 266.6666667   | -266.6666667     |   1066.666667	      | -666.6666667

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 1_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate; // -0.026667%
    assertEq(nextFundingRate, 0); // 0%
    assertEq(currentFundingRate, 266666666666666); // -0.026667%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 4    | 1,000,000	  | 1,000,000    |	0            |	0.026667%         |	266.6666667   |	-266.6666667     |   1066.666667	      | -666.6666667
    // | 5    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.000000%         |	266.6666667   |	-266.6666667     |   1333.333333	      | -933.3333333

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 1_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, 0); // 0%
    assertEq(currentFundingRate, 266666666666666); // 0.026667%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 5    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.000000%         |	 266.6666667   | -266.6666667     |   1333.333333	      | -933.3333333
    // | 6    | 1,000,000	  | 3,000,000    | -2,000,000.00 |-0.026667%          |	0              |	0               |   1333.333333	      | -933.3333333

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, -266666666666666); // -0.026667%
    assertEq(currentFundingRate, 0); // 0%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 6    | 1,000,000	  | 3,000,000    | -2,000,000.00 |-0.026667%         |	0              |	0               |   1333.333333	      | -933.3333333
    // | 7    | 1,000,000	  | 3,000,000    | -2,000,000.00 |-0.053333%         | -266.6666667    |	 800            |   1066.666667	      | -133.3333333

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, -266666666666666); // 0.026667%
    assertEq(currentFundingRate, -266666666666666); // 0.026667%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 7    | 1,000,000	  | 3,000,000    | -2,000,000.00 | -0.053333%         |-266.6666667    |	 800            |   1066.666667	      | -133.3333333
    // | 8    | 2,000,000	  | 3,000,000    | -1,000,000.00 | -0.066667%         |-533.3333333    |	 1600           |   533.3333333	      |  1466.666667

    // Mock global market config as table above
    longPositionSize = 1_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, -266666666666666); // 0.026667%
    assertEq(currentFundingRate, -533333333333332); // 0.053333%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 8    | 2,000,000	  | 3,000,000    | -1,000,000.00 |	-0.066667%         |	-533.3333333    |	 1600           |  533.3333333	      |  1466.666667
    // | 9    | 2,500,000	  | 3,000,000    | -500,000.00   |	-0.073333%         |	-1333.333333    |	 2000           |  -800	              |  3466.666667

    // Mock global market config as table above
    longPositionSize = 2_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, -133333333333333); // -0.013333%
    assertEq(currentFundingRate, -666666666666665); // 0.066667%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 9    | 2,500,000	  | 3,000,000    | -500,000.00   |	-0.073333%         |	-1333.333333    |	 2000           |  -800	              |  3466.666667
    // | 10   | 2,500,000	  | 3,000,000    | -500,000.00   |	-0.080000%         |	-1833.333333    |	 2200           |  -2633.333333	      |  5666.666667

    // Mock global market config as table above
    longPositionSize = 2_500_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, -66666666666666); // 0.00666667%
    assertEq(currentFundingRate, -733333333333331); // 0.073333%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 10   | 2,500,000	  | 3,000,000    | -500,000.00   |	-0.080000%         |	-1833.333333    |	2200           |  -2633.333333	      | 5666.666667
    // | 11   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	-0.040000%         |	-2000           |	2400           |  -4633.333333	      | 8066.666667

    // Mock global market config as table above
    longPositionSize = 2_500_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, -66666666666666); // 0.00666667%
    assertEq(currentFundingRate, -799999999999997); // 0.080000%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 11   | 6,000,000	  | 3,000,000    | 3,000,000.00  | -0.040000%         |	-2000           |	 2400           |  -4633.333333	      |  8066.666667
    // | 12   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	0.000000%         |	-2000           |	 1200           |  -7033.333333	      |  9266.666667

    // Mock global market config as table above
    longPositionSize = 6_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate; // -0.040000%
    assertEq(nextFundingRate, 400000000000000); // 0.040000%
    assertEq(currentFundingRate, -399999999999997); // -0.040000%

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 12   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	0.000000%         |	-2000          |	 1200           |  -7033.333333	      |  9266.666667
    // | 13   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	 0.040000%        |	0              |	0               |  -7033.333333	      |  9266.666667

    // Mock global market config as table above
    longPositionSize = 6_000_000 * 1e30;

    accumFundingRateLong += nextFundingRateLong;

    shortPositionSize = 3_000_000 * 1e30;

    accumFundingRateShort += nextFundingRateShort;

    mockPerpStorage.updateGlobalLongMarketById(marketIndex, longPositionSize, accumFundingRateLong, currentFundingRate);
    mockPerpStorage.updateGlobalShortMarketById(
      marketIndex,
      shortPositionSize,
      accumFundingRateShort,
      currentFundingRate
    );

    nextFundingRate = calculator.getFundingRateVelocity(0);
    currentFundingRate += nextFundingRate;
    assertEq(nextFundingRate, 400000000000000); // 0.040000%
    assertEq(currentFundingRate, 3); // 0.000000%
  }
}
