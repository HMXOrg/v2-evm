// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { console2 } from "forge-std/console2.sol";

contract Calculator_GetGlobalPNLE30Test is Calculator_Base {
  function setUp() public override {
    super.setUp();

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
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0.0004 * 1e18, maxSkewScaleUSD: 300_000_000 * 1e30 })
      }),
      false
    );
  }

  function testCorrectness_WhenGetGlobalPNLE30() external {
    IConfigStorage.MarketConfig memory marketConfig = configStorage.getMarketConfigByIndex(0);
    mockOracle.setPrice(marketConfig.assetId, 32380 * 1e30);
    mockPerpStorage.updateGlobalCounterTradeStates(
      0,
      52674532 * 1e30,
      1528.87843628626564 * 1e30,
      323791928.863313349 * 1e30,
      48927208 * 1e30,
      1478.99298048554020 * 1e30,
      301550790.483496218 * 1e30
    );
    // long global_pnl 2568550.2424053754
    // short global_pnl -422946.3689845529
    // (2568550.2424053754 + -422946.3689845529) = 2145603.87342082
    assertEq(
      calculator.getGlobalPNLE30(),
      2145603873420827528467645024000000000,
      "Global PnL should equal: ~2145603.87342082"
    );
  }
}
