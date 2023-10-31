// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { console2 } from "forge-std/console2.sol";

/// HMX test
import { RebalanceHLPv2Service_BaseForkTest } from "@hmx-test/fork/rebalance-gmx-v2/RebalanceHLPv2Service_Base.t.fork.sol";

contract RebalanceHLPHandler_ScenarioForkTest is RebalanceHLPv2Service_BaseForkTest {
  function setUp() public override {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 143862285);
    super.setUp();
  }

  function testCorrectness_WhenTransitionFromGlpToGM() external {
    SnapshotUint256 memory tvlSnap;
    SnapshotUint256 memory gmTotalSnap;
    SnapshotUint256 memory gmBalanceSnap;

    tvlSnap.before = calculator.getHLPValueE30(false);

    // Withdraw GLP to WETH and USDC.e
    uint256 receivedWeth = rebalanceHLP_withdrawGlp(address(weth), 500_000 ether);
    uint256 receivedUsdc_e = rebalanceHLP_withdrawGlp(address(usdc_e), 500_000 ether);

    // Swap the whole HLP's liquidity in USDC.e to USDC
    address[] memory path = new address[](2);
    path[0] = address(usdc_e);
    path[1] = address(usdc);
    uint256 receivedUsdc = rebalanceHLP_swap(receivedUsdc_e, path);

    // Snap
    gmTotalSnap.before = vaultStorage.totalAmount(address(gmETHUSD));
    gmBalanceSnap.before = gmETHUSD.balanceOf(address(vaultStorage));

    // Deploy WETH and USDC to GM(ETH-USDC)
    bytes32 gmxOrderKey = rebalanceHLPv2_createDepositOrder(GM_ETHUSDC_ASSET_ID, receivedWeth, receivedUsdc, 0);
    gmxV2Keeper_executeDepositOrder(GM_ETHUSDC_ASSET_ID, gmxOrderKey);

    // Snap
    gmTotalSnap.after1 = vaultStorage.totalAmount(address(gmETHUSD));
    gmBalanceSnap.after1 = gmETHUSD.balanceOf(address(vaultStorage));
    tvlSnap.after1 = calculator.getHLPValueE30(false);

    // Asserts
    assertTrue(gmTotalSnap.after1 > gmTotalSnap.before, "GM(ETHUSDC) total should increase");
    assertTrue(gmBalanceSnap.after1 > gmBalanceSnap.before, "GM(ETHUSDC) balance should increase");
    assertApproxEqAbs(tvlSnap.before, tvlSnap.after1, 8_000 * 1e30, "HLP's TVL should not drop more than 8_000 USD");
  }
}
