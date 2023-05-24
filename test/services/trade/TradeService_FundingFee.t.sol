// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { MockCalculatorWithRealCalculator } from "../../mocks/MockCalculatorWithRealCalculator.sol";

contract TradeService_FundingFee is TradeService_Base {
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
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getFundingFee");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
      tradeHelper.reloadConfig();
    }

    // Set PLPLiquidity
    vaultStorage.addPLPLiquidity(configStorage.getPlpTokens()[0], 1000 * 1e18);

    // Ignore Borrowing fee on this test
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({ baseBorrowingRate: 0 });
    configStorage.setAssetClassConfigByIndex(0, _cryptoConfig);

    // Ignore Developer fee on this test
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({ fundingInterval: 1, devFeeRateBPS: 0, minProfitDuration: 0, maxPosition: 5 })
    );

    // Set funding rate config
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(ethMarketIndex);
    _marketConfig.fundingRate.maxFundingRate = 0.00000289 * 1e18; // 25% per day
    _marketConfig.fundingRate.maxSkewScaleUSD = 10_000_000 * 1e30;

    configStorage.setMarketConfig(ethMarketIndex, _marketConfig);
  }

  function testCorrectness_fundingFee() external {
    // Set fundingFee to have enough token amounts to repay funding fee
    vaultStorage.addFundingFee(configStorage.getPlpTokens()[0], 10 * 1e18);

    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1 USD
    mockOracle.setPrice(1600 * 1e30);
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(weth), 1 * 1e18);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 1_000_000 * 1e6);
    vaultStorage.increaseTraderBalance(BOB, address(usdt), 5_000_000 * 1e6);
    vaultStorage.increaseTraderBalance(CAROL, address(usdt), 5_000_000 * 1e6);

    vm.warp(1);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30, 0);
      tradeService.increasePosition(BOB, 0, ethMarketIndex, 2_000_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertEq(_market.currentFundingRate, 0);

      assertEq(_market.longPositionSize, 2_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 1_000_000 * 1e30);
      assertEq(_market.longPositionSize - _market.shortPositionSize, 1_000_000 * 1e30);

      vm.warp(block.timestamp + 1); // warp 1 second to inspect the latest funding velocity
      assertEq(mockCalculator.getFundingRateVelocity(ethMarketIndex), -0.000000289 * 1e18);
    }

    vm.warp(21001);
    {
      tradeService.increasePosition(CAROL, 0, ethMarketIndex, -500_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertEq(_market.currentFundingRate, -0.006069 * 1e18);

      assertEq(_market.longPositionSize, 2_000_000 * 1e30);
      assertEq(_market.shortPositionSize, 1_500_000 * 1e30);
      assertEq(_market.longPositionSize - _market.shortPositionSize, 500_000 * 1e30);
      assertEq(_market.fundingAccrued, 0);

      // Alice position funding fee
      IPerpStorage.Position memory alicePosition = perpStorage.getPositionById(getPositionId(ALICE, 0, ethMarketIndex));
      assertEq(
        mockCalculator.getFundingFee(
          false,
          _abs(alicePosition.positionSizeE30),
          _market.fundingAccrued,
          alicePosition.entryFundingRate
        ),
        738.450038580246882702 * 1e30
      );

      vm.warp(block.timestamp + 1); // warp 1 second to inspect the latest funding velocity
      assertApproxEqRel(
        mockCalculator.getFundingRateVelocity(ethMarketIndex),
        -0.000000144675925926 * 1e18,
        0.01 ether
      );
    }
  }

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
