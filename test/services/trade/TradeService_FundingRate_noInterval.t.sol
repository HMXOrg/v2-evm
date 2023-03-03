// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { TradeService } from "../../../src/services/TradeService.sol";

import { Calculator_Base } from "../../calculator/Calculator_Base.t.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";

contract TradeService_FundingRate is Calculator_Base {
  TradeService tradeService;

  function setUp() public virtual override {
    super.setUp();

    // deploy services
    tradeService = new TradeService(address(mockPerpStorage), address(mockVaultStorage), address(configStorage));

    mockOracle.setExponent(-8);

    // Set market config
    // maxFundingRateBPS = 0.04%
    // maxSkewScaleUSD = 3m USD
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: wbtcAssetId,
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

  function testCorrectness_getNextFundingRate_noInterval() external {
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 1    | 2,000,000	  | 1,000,000    |	1,000,000    |	-0.013333%        |	0              |	0               |  0	                | 0
    // | 2    | 2,000,000	  | 1,000,000    |	1,000,000    |	-0.026667%        |	-266.6666667   |	133.3333333     |  -266.6666667	      | 133.3333333

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

    (int256 newfundingRate, int256 nextfundingRateLong, int256 nextfundingRateShort) = tradeService.getNextFundingRate(
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

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 2    | 2,000,000	  | 1,000,000    |	1,000,000    |	-0.026667%        |	-266.6666667   |	133.3333333     |  -266.6666667	      | 133.3333333
    // | 3    | 1,000,000	  | 1,000,000    |	0            |	-0.026667%        |	-533.3333333   |	266.6666667     |  -800	              | 400

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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // -0.026667%
    assertEq(newfundingRate, -266666666666666); // -0.026667%

    assertEq(nextfundingRateLong, -533333333333332000000); // -533.3333333
    assertEq(nextfundingRateShort, 266666666666666000000); // 266.6666667

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -266666666666666000000); // -266.6666667
    assertEq(accumFundingRateShort, 133333333333333000000); // 133.3333333

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 3    | 1,000,000	  | 1,000,000    |	0            |	-0.026667%        |	-533.3333333   |	266.6666667     |  -800	              | 400
    // | 4    | 1,000,000	  | 1,000,000    |	0            |	-0.026667%        |	-266.6666667   |	266.6666667     |  -1066.666667	      | 666.6666667

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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // -0.026667%
    assertEq(newfundingRate, -266666666666666); // -0.026667%

    assertEq(nextfundingRateLong, -266666666666666000000); // 266.6666667
    assertEq(nextfundingRateShort, 266666666666666000000); // 266.6666667

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -799999999999998000000); // ~ -800
    assertEq(accumFundingRateShort, 399999999999999000000); // ~ 400

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 4    | 1,000,000	  | 1,000,000    |	0            |	-0.026667%        |	-266.6666667   |	266.6666667     |  -1066.666667	      | 666.6666667
    // | 5    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.000000%         |	-266.6666667   |	266.6666667     |  -1333.333333	      | 933.3333333

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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // -0.026667%
    assertEq(newfundingRate, -266666666666666); // -0.026667%

    assertEq(nextfundingRateLong, -266666666666666000000); // 266.6666667
    assertEq(nextfundingRateShort, 266666666666666000000); // 266.6666667

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -1066666666666664000000); // -1066.666667
    assertEq(accumFundingRateShort, 666666666666665000000); // 666.6666667

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 5    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.000000%         |	-266.6666667   |	266.6666667     |  -1333.333333	      | 933.3333333
    // | 6    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.026667%         |	0              |	0               |  -1333.333333	      | 933.3333333

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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0%
    assertEq(newfundingRate, 0); // 0%

    assertEq(nextfundingRateLong, 0); // 0
    assertEq(nextfundingRateShort, 0); // 0

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -1333333333333330000000); // -1333.333333
    assertEq(accumFundingRateShort, 933333333333331000000); // 933.3333333

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 6    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.026667%         |	0              |	0               |  -1333.333333	      | 933.3333333
    // | 7    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.053333%         |	266.6666667    |	-800            |  -1066.666667	      | 133.3333333

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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0.026667%
    assertEq(newfundingRate, 266666666666666); // 0.026667%

    assertEq(nextfundingRateLong, 266666666666666000000); // 266.6666667
    assertEq(nextfundingRateShort, -799999999999998000000); // -800

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -1333333333333330000000); // -1333.333333
    assertEq(accumFundingRateShort, 933333333333331000000); // 933.3333333

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 7    | 1,000,000	  | 3,000,000    | -2,000,000.00 |	0.053333%         |	266.6666667    |	-800            |  -1066.666667	      | 133.3333333
    // | 8    | 2,000,000	  | 3,000,000    | -1,000,000.00 |	0.066667%         |	533.3333333    |	-1600           |  -533.3333333	      | -1466.666667

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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0.053333%
    assertEq(newfundingRate, 533333333333332); // 0.053333%

    assertEq(nextfundingRateLong, 533333333333332000000); // 533.3333333
    assertEq(nextfundingRateShort, -1599999999999996000000); // -1600

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -1066666666666664000000); // -1066.666667
    assertEq(accumFundingRateShort, 133333333333333000000); // 133.3333333

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 8    | 2,000,000	  | 3,000,000    | -1,000,000.00 |	0.066667%         |	533.3333333    |	-1600           |  -533.3333333	      | -1466.666667
    // | 9    | 2,500,000	  | 3,000,000    | -500,000.00   |	0.073333%         |	1333.333333    |	-2000           |  800	              | -3466.666667

    // Mock global market config as table above
    longPositionSize = 2_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 100 * 10 ** 8;
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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0.066667%
    assertEq(newfundingRate, 666666666666665); // 0.066667%

    assertEq(nextfundingRateLong, 1333333333333330000000); // 1333.333333
    assertEq(nextfundingRateShort, -1999999999999995000000); // -2000

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, -533333333333332000000); // -533.3333333
    assertEq(accumFundingRateShort, -1466666666666663000000); // -1466.666667

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 9    | 2,500,000	  | 3,000,000    | -500,000.00   |	0.073333%         |	1333.333333    |	-2000           |  800	              | -3466.666667
    // | 10   | 2,500,000	  | 3,000,000    | -500,000.00   |	0.080000%         |	1833.333333    |	-2200           |  2633.333333	      | -5666.666667

    // Mock global market config as table above
    longPositionSize = 2_500_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 125 * 10 ** 8;
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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0.073333%
    assertEq(newfundingRate, 733333333333331); // 0.073333%

    assertEq(nextfundingRateLong, 1833333333333327500000); // 1833.333333
    assertEq(nextfundingRateShort, -2199999999999993000000); // -2200

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, 799999999999998000000); // 800
    assertEq(accumFundingRateShort, -3466666666666658000000); // -3466.666667

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 10   | 2,500,000	  | 3,000,000    | -500,000.00   |	0.080000%         |	1833.333333    |	-2200           |  2633.333333	      | -5666.666667
    // | 11   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	0.040000%         |	2000           |	-2400           |  4633.333333	      | -8066.666667

    // Mock global market config as table above
    longPositionSize = 2_500_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 125 * 10 ** 8;
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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0.080000%
    assertEq(newfundingRate, 799999999999997); // 0.080000%

    assertEq(nextfundingRateLong, 1999999999999992500000); // 2000
    assertEq(nextfundingRateShort, -2399999999999991000000); // -2400

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, 2633333333333325500000); // 2633.333333
    assertEq(accumFundingRateShort, -5666666666666651000000); // -5666.666667

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 11   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	0.040000%         |	2000           |	-2400           |  4633.333333	      | -8066.666667
    // | 12   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	0.000000%         |	2000           |	-1200           |  7033.333333	      | -9266.666667

    // Mock global market config as table above
    longPositionSize = 6_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 300 * 10 ** 8;
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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0.040000%
    assertEq(newfundingRate, 399999999999997); // 0.040000%

    assertEq(nextfundingRateLong, 2399999999999982000000); // 2400
    assertEq(nextfundingRateShort, -1199999999999991000000); // -1200

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, 4633333333333318000000); // 4633.333333
    assertEq(accumFundingRateShort, -8066666666666642000000); // -8066.666667

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | Row  | LongSizeUSD | ShortSizeUSD | MarketSkewUSD | CurrentFundingRate | LongFundingFee |	ShortFundingFee	|	LongFundingAccrued	| ShortFundingAccrued |
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // | 12   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	0.000000%         |	2000           |	-1200           |  7033.333333	      | -9266.666667
    // | 13   | 6,000,000	  | 3,000,000    | 3,000,000.00  |	-0.040000%        |	0              |	0               |  7033.333333	      | -9266.666667

    // Mock global market config as table above
    longPositionSize = 6_000_000 * 1e30;
    longAvgPrice = 20_000 * 1e30;
    longOpenInterest = 300 * 10 ** 8;
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

    (newfundingRate, nextfundingRateLong, nextfundingRateShort) = tradeService.getNextFundingRate(0, 0);
    currentFundingRate = newfundingRate; // 0.000000%
    assertEq(newfundingRate, -3); // 0.000000%

    assertEq(nextfundingRateLong, -18000000); // 0
    assertEq(nextfundingRateShort, 9000000); // 0

    (accumFundingRateLong, accumFundingRateShort) = mockPerpStorage.getGlobalMarketInfo(marketIndex);
    assertEq(accumFundingRateLong, 7033333333333300000000); // 7033.333333
    assertEq(accumFundingRateShort, -9266666666666633000000); // -9266.666667
  }
}
