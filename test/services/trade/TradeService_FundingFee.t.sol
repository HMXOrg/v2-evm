// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { MockCalculatorWithRealCalculator } from "../../mocks/MockCalculatorWithRealCalculator.sol";
import { console2 } from "forge-std/console2.sol";

contract TradeService_FundingFee is TradeService_Base {
  uint256 constant MAX_DIFF = 0.0000000001 ether;

  function setUp() public virtual override {
    super.setUp();

    // Override the mock calculator
    {
      mockCalculator = new MockCalculatorWithRealCalculator(
        address(proxyAdmin),
        address(mockOracle),
        address(vaultStorage),
        address(perpStorage),
        address(configStorage)
      );
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getFundingRateVelocity");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("proportionalElapsedInDay");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getFundingFee");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
      tradeHelper.reloadConfig();
    }

    // Set HLPLiquidity
    vaultStorage.addHLPLiquidity(configStorage.getHlpTokens()[0], 1000 * 1e18);

    // Ignore Borrowing fee on this test
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({ baseBorrowingRate: 0 });
    configStorage.setAssetClassConfigByIndex(0, _cryptoConfig);

    // Ignore Developer fee on this test
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({ fundingInterval: 1, devFeeRateBPS: 0, minProfitDuration: 0, maxPosition: 5 })
    );

    // Set funding rate config
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(ethMarketIndex);
    _marketConfig.fundingRate.maxFundingRate = 0.25 * 1e18; // 25% per day
    _marketConfig.fundingRate.maxSkewScaleUSD = 10_000_000 * 1e30;
    _marketConfig.maxLongPositionSize = 100_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 100_000_000 * 1e30;

    configStorage.setMarketConfig(ethMarketIndex, _marketConfig, false, 0);
  }

  function testCorrectness_fundingFee() external {
    // Set fundingFee to have enough token amounts to repay funding fee
    vaultStorage.addFundingFee(configStorage.getHlpTokens()[0], 10 * 1e18);

    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setHLPValue(100_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 1_000_000 * 1e6);
    vaultStorage.increaseTraderBalance(BOB, address(usdt), 1_000_000 * 1e6);
    vaultStorage.increaseTraderBalance(CAROL, address(usdt), 5_000_000 * 1e6);
    vaultStorage.increaseTraderBalance(DAVE, address(usdt), 5_000_000 * 1e6);

    // https://github.com/davidvuong/perpsv2-funding/blob/master/main.ipynb

    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // |     0 |      0 |  3,000,000.000000000000000000 |  1,000,000.000000000000000000 | 0.000000000000000000 |                 0.025 |  0.000000000000000000 |      0.000000000000000000 |     0.000000000000000000 |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // |     1 |  21000 |  3,500,000.000000000000000000 |    500,000.000000000000000000 | 0.00607638888888889  |                0.0125 |  0.000738450038580247 |         -738.450038580247 |        1,476.90007716049 |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // |     2 |  31000 |  4,000,000.000000000000000000 |          0.000000000000000000 | 0.00752314814814815  |  0.000000000000000000 |  0.001525460283779150 |        -1,525.46028377915 | 3,050.920567558300000000 |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // |     3 |  51000 |  9,000,000.000000000000000000 | -5,000,000.000000000000000000 | 0.00752314814814815  | -0.125000000000000000 |   0.00326692976251715 | -3,266.929762517150000000 | 6,533.859525034290000000 |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // |     4 |  81000 | 13,000,000.000000000000000000 | -1,000,000.000000000000000000 |  -0.0358796296296296 |                -0.025 |   -0.0016560704946845 |          1,656.0704946845 |         -3,312.140989369 |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // |     5 | 121000 | 24,000,000.000000000000000000 | 10,000,000.000000000000000000 |  -0.0474537037037037 |  0.250000000000000000 |   -0.0209461939514746 |         20,946.1939514746 |       -41,892.3879029492 |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
    // |     6 | 151000 | 34,000,000.000000000000000000 |          0.000000000000000000 |  0.0393518518518518  |  0.000000000000000000 |   -0.0223527654535322 |         22,352.7654535322 |       -44,705.5309070645 |
    // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|

    vm.warp(1);
    {
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // |     0 |      0 |  3,000,000.000000000000000000 |  1,000,000.000000000000000000 | 0.000000000000000000 |                 0.025 |  0.000000000000000000 |      0.000000000000000000 |     0.000000000000000000 |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30, 0);
      tradeService.increasePosition(BOB, 0, ethMarketIndex, 2_000_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertEq(_market.currentFundingRate, 0);

      assertEq(_market.longPositionSize, 2_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 1_000_000 * 1e30);
      assertEq(_market.longPositionSize - _market.shortPositionSize, 1_000_000 * 1e30);
      assertEq(_market.fundingAccrued, 0);

      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), 0.025 * 1e18);
    }

    vm.warp(21001);
    {
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // |     1 |  21000 |  3,500,000.000000000000000000 |    500,000.000000000000000000 |  0.00607638888888889 |                0.0125 |  0.000738450038580247 |         -738.450038580247 |        1,476.90007716049 |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      tradeService.increasePosition(CAROL, 0, ethMarketIndex, -500_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertApproxEqRel(_market.currentFundingRate, 0.0060763888888888 * 1e18, MAX_DIFF);

      assertEq(_market.longPositionSize, 2_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 1_500_000 * 1e30);
      assertEq(_market.longPositionSize - _market.shortPositionSize, 500_000 * 1e30);
      assertEq(_market.fundingAccrued, 0.000738450038580246 * 1e18);

      IPerpStorage.Position memory alicePosition = perpStorage.getPositionById(getPositionId(ALICE, 0, ethMarketIndex));
      console2.log(alicePosition.positionSizeE30);
      console2.log(alicePosition.lastFundingAccrued);
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          alicePosition.positionSizeE30,
          _market.fundingAccrued,
          alicePosition.lastFundingAccrued
        ),
        -738.450038580246882702 * 1e30,
        MAX_DIFF
      );
      IPerpStorage.Position memory bobPosition = perpStorage.getPositionById(getPositionId(BOB, 0, ethMarketIndex));
      console2.log(bobPosition.positionSizeE30);
      console2.log(bobPosition.lastFundingAccrued);
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          bobPosition.positionSizeE30,
          _market.fundingAccrued,
          bobPosition.lastFundingAccrued
        ),
        1476.900077160493765405 * 1e30,
        MAX_DIFF
      );

      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), 0.0125 * 1e18);
    }

    vm.warp(31001);
    {
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // |     2 |  31000 |  4,000,000.000000000000000000 |          0.000000000000000000 |  0.00752314814814815 |  0.000000000000000000 |  0.001525460283779150 |        -1,525.46028377915 | 3,050.920567558300000000 |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      tradeService.increasePosition(CAROL, 0, ethMarketIndex, -500_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertApproxEqRel(_market.currentFundingRate, 0.007523148148148149 * 1e18, MAX_DIFF);

      assertEq(_market.longPositionSize, 2_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 2_000_000 * 1e30);
      assertEq(_market.longPositionSize - _market.shortPositionSize, 0);
      assertApproxEqRel(_market.fundingAccrued, 0.001525460283779150 * 1e18, MAX_DIFF);

      IPerpStorage.Position memory alicePosition = perpStorage.getPositionById(getPositionId(ALICE, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          alicePosition.positionSizeE30,
          _market.fundingAccrued,
          alicePosition.lastFundingAccrued
        ),
        -1525.460283779149676775 * 1e30,
        MAX_DIFF
      );
      IPerpStorage.Position memory bobPosition = perpStorage.getPositionById(getPositionId(BOB, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          bobPosition.positionSizeE30,
          _market.fundingAccrued,
          bobPosition.lastFundingAccrued
        ),
        3050.920567558299353550 * 1e30,
        MAX_DIFF
      );

      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), 0);
    }

    vm.warp(51001);
    {
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // |     3 |  51000 |  9,000,000.000000000000000000 | -5,000,000.000000000000000000 |  0.00752314814814815 | -0.125000000000000000 |   0.00326692976251715 | -3,266.929762517150000000 | 6,533.859525034290000000 |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      tradeService.increasePosition(CAROL, 0, ethMarketIndex, -5_000_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertApproxEqRel(_market.currentFundingRate, 0.0075231481 * 1e18, 0.000001 ether);

      assertEq(_market.longPositionSize, 2_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 7_000_000 * 1e30);
      assertEq(int256(_market.longPositionSize) - int256(_market.shortPositionSize), -5_000_000 * 1e30);
      assertApproxEqRel(_market.fundingAccrued, 0.00326692976 * 1e18, 0.0001 ether);

      IPerpStorage.Position memory alicePosition = perpStorage.getPositionById(getPositionId(ALICE, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          alicePosition.positionSizeE30,
          _market.fundingAccrued,
          alicePosition.lastFundingAccrued
        ),
        -3266.929762517147082690 * 1e30,
        MAX_DIFF
      );
      IPerpStorage.Position memory bobPosition = perpStorage.getPositionById(getPositionId(BOB, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          bobPosition.positionSizeE30,
          _market.fundingAccrued,
          bobPosition.lastFundingAccrued
        ),
        6533.859525034294165380 * 1e30,
        MAX_DIFF
      );

      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), -0.125 * 1e18);
    }

    vm.warp(81001);
    {
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // |     4 |  81000 | 13,000,000.000000000000000000 | -1,000,000.000000000000000000 |  -0.0358796296296296 |                -0.025 |   -0.0016560704946845 |          1,656.0704946845 |         -3,312.140989369 |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      tradeService.increasePosition(DAVE, 0, ethMarketIndex, 4_000_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertApproxEqRel(_market.currentFundingRate, -0.035879629629629629 * 1e18, 0.000001 ether);

      assertEq(_market.longPositionSize, 6_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 7_000_000 * 1e30);
      assertEq(int256(_market.longPositionSize) - int256(_market.shortPositionSize), -1_000_000 * 1e30);
      assertApproxEqRel(_market.fundingAccrued, -0.001656070494684499 * 1e18, 0.0001 ether);

      IPerpStorage.Position memory alicePosition = perpStorage.getPositionById(getPositionId(ALICE, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          alicePosition.positionSizeE30,
          _market.fundingAccrued,
          alicePosition.lastFundingAccrued
        ),
        1656.070494684498726201 * 1e30,
        MAX_DIFF
      );
      IPerpStorage.Position memory bobPosition = perpStorage.getPositionById(getPositionId(BOB, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          bobPosition.positionSizeE30,
          _market.fundingAccrued,
          bobPosition.lastFundingAccrued
        ),
        -3312.140989368997452402 * 1e30,
        MAX_DIFF
      );

      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), -0.025 * 1e18);
    }

    vm.warp(121001);
    {
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // |     5 | 121000 | 24,000,000.000000000000000000 | 10,000,000.000000000000000000 |  -0.0474537037037037 |  0.250000000000000000 |   -0.0209461939514746 |         20,946.1939514746 |       -41,892.3879029492 |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      tradeService.increasePosition(DAVE, 0, ethMarketIndex, 11_000_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertApproxEqRel(_market.currentFundingRate, -0.047453703703703706 * 1e18, 0.000001 ether);

      assertEq(_market.longPositionSize, 17_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 7_000_000 * 1e30);
      assertEq(int256(_market.longPositionSize) - int256(_market.shortPositionSize), 10_000_000 * 1e30);
      assertApproxEqRel(_market.fundingAccrued, -0.020946193951474623 * 1e18, 0.0001 ether);

      IPerpStorage.Position memory alicePosition = perpStorage.getPositionById(getPositionId(ALICE, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          alicePosition.positionSizeE30,
          _market.fundingAccrued,
          alicePosition.lastFundingAccrued
        ),
        20946.193951474622735986 * 1e30,
        MAX_DIFF
      );
      IPerpStorage.Position memory bobPosition = perpStorage.getPositionById(getPositionId(BOB, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          bobPosition.positionSizeE30,
          _market.fundingAccrued,
          bobPosition.lastFundingAccrued
        ),
        -41892.387902949245471973 * 1e30,
        MAX_DIFF
      );

      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), 0.25 * 1e18);
    }

    vm.warp(151001);
    {
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // | index | t      | size_usd                      | skew_usd                      | funding_rate         | funding_velocity      | funding_accrued       | funding_accrued_p1_usd    | funding_accrued_p2_usd   |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      // |     6 | 151000 | 34,000,000.000000000000000000 |          0.000000000000000000 |   0.0393518518518518 |  0.000000000000000000 |   -0.0223527654535322 |         22,352.7654535322 |       -44,705.5309070645 |
      // |-------|--------|-------------------------------|-------------------------------|----------------------|-----------------------|-----------------------|---------------------------|--------------------------|
      tradeService.increasePosition(CAROL, 0, ethMarketIndex, -10_000_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertApproxEqRel(_market.currentFundingRate, 0.039351851851851846 * 1e18, 0.000001 ether);

      assertEq(_market.longPositionSize, 17_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 17_000_000 * 1e30);
      assertEq(int256(_market.longPositionSize) - int256(_market.shortPositionSize), 0);
      assertApproxEqRel(_market.fundingAccrued, -0.022352765453532236 * 1e18, 0.0001 ether);

      IPerpStorage.Position memory alicePosition = perpStorage.getPositionById(getPositionId(ALICE, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          alicePosition.positionSizeE30,
          _market.fundingAccrued,
          alicePosition.lastFundingAccrued
        ),
        22352.765453532236278988 * 1e30,
        MAX_DIFF
      );
      IPerpStorage.Position memory bobPosition = perpStorage.getPositionById(getPositionId(BOB, 0, ethMarketIndex));
      assertApproxEqRel(
        mockCalculator.getFundingFee(
          bobPosition.positionSizeE30,
          _market.fundingAccrued,
          bobPosition.lastFundingAccrued
        ),
        -44705.530907064472557977 * 1e30,
        MAX_DIFF
      );

      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), 0);
    }

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(0), 0);
    assertEq(vaultStorage.traderBalances(ALICE, address(usdt)), (1000000 * 1e6 - 22352.765453 * 1e6));

    tradeService.decreasePosition(BOB, 0, ethMarketIndex, 1_000_000 * 1e30, address(0), 0);
    assertEq(vaultStorage.traderBalances(BOB, address(usdt)), (1000000 * 1e6 + 44705.530907 * 1e6));
  }

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
