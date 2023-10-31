// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { console2 } from "forge-std/console2.sol";

/// HMX Test
import { RebalanceHLPv2Service_BaseForkTest } from "@hmx-test/fork/rebalance-gmx-v2/RebalanceHLPv2_Base.t.fork.sol";
import { MockEcoPyth } from "@hmx-test/mocks/MockEcoPyth.sol";

contract RebalanceHLPv2Service_WithdrawalForkTest is RebalanceHLPv2Service_BaseForkTest {
  function setUp() public override {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 143862285);
    super.setUp();
    // Deploy some WETH to GM(ETH-USDC)
    bytes32 gmxV2OrderKey = rebalanceHLPv2_createDepositOrder(GM_ETHUSDC_ASSET_ID, 4.9 ether, 0 ether, 0);
    assertEq(vaultStorage.hlpLiquidityOnHold(address(weth)), 4.9 ether, "WETH liquidity on hold should be 60 ETH");
    gmxV2Keeper_executeDepositOrder(GM_ETHUSDC_ASSET_ID, gmxV2OrderKey);
    assertEq(vaultStorage.hlpLiquidityOnHold(address(weth)), 0, "WETH liquidity on hold should be 0 ETH");
    // Received GMs: 8912412145575829437123
  }

  function testRevert_WhenWithdrawMoreThanLiquidity() external {
    rebalanceHLPv2_createWithdrawalOrder(
      GM_ETHUSDC_ASSET_ID,
      8912412145575829437124,
      0,
      0,
      "IVaultStorage_HLPBalanceRemaining()"
    );
  }

  function testCorrectness_WhenNoOneJamInTheMiddle() external {
    SnapshotUint256 memory tvlSnap;
    SnapshotUint256 memory aumSnap;
    SnapshotUint256 memory gmEthBalanceSnap;
    SnapshotUint256 memory gmEthTotalSnap;
    SnapshotUint256 memory wethBalanceSnap;
    SnapshotUint256 memory wethTotalSnap;
    SnapshotUint256 memory wethLiquiditySnap;
    SnapshotUint256 memory usdcBalanceSnap;
    SnapshotUint256 memory usdcTotalSnap;
    SnapshotUint256 memory usdcLiquiditySnap;

    tvlSnap.before = calculator.getHLPValueE30(false);
    aumSnap.before = calculator.getAUME30(false);
    gmEthBalanceSnap.before = gmETHUSD.balanceOf(address(vaultStorage));
    gmEthTotalSnap.before = vaultStorage.totalAmount(address(gmETHUSD));

    // Create withdrawal orders
    bytes32 gmxOrderKey = rebalanceHLPv2_createWithdrawalOrder(GM_ETHUSDC_ASSET_ID, 8912412145575829437123, 0, 0);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);
    gmEthBalanceSnap.after1 = gmETHUSD.balanceOf(address(vaultStorage));
    gmEthTotalSnap.after1 = vaultStorage.totalAmount(address(gmETHUSD));

    assertEq(
      vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)),
      8912412145575829437123,
      "GM(ETH-USDC) liquidity on hold should be 8912412145575829437123"
    );
    assertEq(tvlSnap.after1, tvlSnap.before, "TVL should not change");
    assertEq(aumSnap.after1, aumSnap.before, "AUM should not change");
    assertEq(gmEthBalanceSnap.after1, 0, "GM(ETH-USDC) balance should be 0");
    assertEq(gmEthTotalSnap.after1, gmEthTotalSnap.before, "GM(ETH-USDC) total should not change");

    tvlSnap.before = tvlSnap.after1;
    aumSnap.before = aumSnap.after1;
    gmEthBalanceSnap.before = gmEthBalanceSnap.after1;
    gmEthTotalSnap.before = gmEthTotalSnap.after1;
    wethBalanceSnap.before = weth.balanceOf(address(vaultStorage));
    wethTotalSnap.before = vaultStorage.totalAmount(address(weth));
    wethLiquiditySnap.before = vaultStorage.hlpLiquidity(address(weth));
    usdcBalanceSnap.before = usdc.balanceOf(address(vaultStorage));
    usdcTotalSnap.before = vaultStorage.totalAmount(address(usdc));
    usdcLiquiditySnap.before = vaultStorage.hlpLiquidity(address(usdc));

    // Execute withdrawal orders
    gmxV2Keeper_executeWithdrawalOrder(GM_ETHUSDC_ASSET_ID, gmxOrderKey);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);
    gmEthBalanceSnap.after1 = gmETHUSD.balanceOf(address(vaultStorage));
    gmEthTotalSnap.after1 = vaultStorage.totalAmount(address(gmETHUSD));
    wethBalanceSnap.after1 = weth.balanceOf(address(vaultStorage));
    wethTotalSnap.after1 = vaultStorage.totalAmount(address(weth));
    wethLiquiditySnap.after1 = vaultStorage.hlpLiquidity(address(weth));
    usdcBalanceSnap.after1 = usdc.balanceOf(address(vaultStorage));
    usdcTotalSnap.after1 = vaultStorage.totalAmount(address(usdc));
    usdcLiquiditySnap.after1 = vaultStorage.hlpLiquidity(address(usdc));

    assertEq(
      rebalanceHLPv2Service.getPendingWithdrawal(gmxOrderKey).market,
      address(0),
      "Withdrawal order should be deleted"
    );
    assertEq(vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity on hold should be 0");
    assertApproxEqAbs(tvlSnap.after1, tvlSnap.before, 5_000 * 1e30, "TVL should not change more than 5,000 USD");
    assertApproxEqAbs(aumSnap.after1, aumSnap.before, 5_000 * 1e30, "AUM should not change more than 5,000 USD");
    assertEq(gmEthBalanceSnap.after1, 0, "GM(ETH-USDC) balance should be 0");
    assertEq(gmEthTotalSnap.after1, 0, "GM(ETH-USDC) after executed total should be 0");
    assertEq(
      wethBalanceSnap.before + 2522039333159539803,
      wethBalanceSnap.after1,
      "WETH balance should increase by 2522039333159539803"
    );
    assertEq(
      wethTotalSnap.before + 2522039333159539803,
      wethTotalSnap.after1,
      "WETH total should increase by 2522039333159539803"
    );
    assertEq(wethTotalSnap.after1, wethBalanceSnap.after1, "WETH total should equal to WETH balance");
    assertEq(
      wethLiquiditySnap.before + 2522039333159539803,
      wethLiquiditySnap.after1,
      "WETH liquidity should increase"
    );
    assertEq(usdcBalanceSnap.before + 4226796583, usdcBalanceSnap.after1, "USDC balance should increase by 4226796583");
    assertEq(usdcTotalSnap.before + 4226796583, usdcTotalSnap.after1, "USDC total should increase by 4226796583");
    assertEq(usdcTotalSnap.after1, usdcBalanceSnap.after1, "USDC total should equal to USDC balance");
    assertEq(usdcLiquiditySnap.before + 4226796583, usdcLiquiditySnap.after1, "USDC liquidity should increase");
  }

  function testCorrectness_WhenErr_WhenNoOneJamInTheMiddle() external {
    uint256 tvlBefore = calculator.getHLPValueE30(false);
    uint256 aumBefore = calculator.getAUME30(false);
    uint256 gmEthBalanceBefore = gmETHUSD.balanceOf(address(vaultStorage));
    uint256 gmEthTotalBefore = vaultStorage.totalAmount(address(gmETHUSD));

    // Create withdrawal orders
    bytes32 gmxOrderKey = rebalanceHLPv2_createWithdrawalOrder(
      GM_ETHUSDC_ASSET_ID,
      8912412145575829437123,
      2522039333159539804,
      0
    );

    uint256 tvlAfter = calculator.getHLPValueE30(false);
    uint256 aumAfter = calculator.getAUME30(false);
    uint256 gmEthBalanceAfter = gmETHUSD.balanceOf(address(vaultStorage));
    uint256 gmEthTotalAfter = vaultStorage.totalAmount(address(gmETHUSD));

    assertEq(
      vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)),
      8912412145575829437123,
      "GM(ETH-USDC) liquidity on hold should be 8912412145575829437123"
    );
    assertEq(tvlAfter, tvlBefore, "TVL should not change");
    assertEq(aumAfter, aumBefore, "AUM should not change");
    assertEq(gmEthBalanceAfter, 0, "GM(ETH-USDC) balance should be 0");
    assertEq(gmEthTotalAfter, gmEthTotalBefore, "GM(ETH-USDC) total should not change");

    tvlBefore = tvlAfter;
    aumBefore = aumAfter;
    gmEthBalanceBefore = gmEthBalanceAfter;
    gmEthTotalBefore = gmEthTotalAfter;

    // Execute withdrawal orders
    gmxV2Keeper_executeWithdrawalOrder(GM_ETHUSDC_ASSET_ID, gmxOrderKey);

    tvlAfter = calculator.getHLPValueE30(false);
    aumAfter = calculator.getAUME30(false);
    gmEthBalanceAfter = gmETHUSD.balanceOf(address(vaultStorage));
    gmEthTotalAfter = vaultStorage.totalAmount(address(gmETHUSD));

    assertEq(vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity on hold should be 0");
    assertEq(
      vaultStorage.hlpLiquidity(address(gmETHUSD)),
      8912412145575829437123,
      "GM(ETH-USDC) liquidity should revert to 8912412145575829437123"
    );
    assertEq(tvlAfter, tvlBefore, "TVL should not change");
    assertEq(aumAfter, aumBefore, "AUM should not change");
    assertEq(gmEthBalanceAfter, 8912412145575829437123, "GM(ETH-USDC) balance should be 8912412145575829437123");
    assertEq(
      gmEthTotalAfter,
      8912412145575829437123,
      "GM(ETH-USDC) after executed total should be 8912412145575829437123"
    );
  }

  function testCorrectness_WhenSomeoneJamInTheMiddle_AddRemoveLiquidity() external {
    SnapshotUint256 memory tvlSnap;
    SnapshotUint256 memory aumSnap;

    tvlSnap.before = calculator.getHLPValueE30(false);
    aumSnap.before = calculator.getAUME30(false);

    // Create withdrawal orders
    bytes32 gmxOrderKey = rebalanceHLPv2_createWithdrawalOrder(GM_ETHUSDC_ASSET_ID, 8912412145575829437123, 0, 0);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);

    // Asserts
    assertEq(tvlSnap.before, tvlSnap.after1, "TVL should not change");
    assertEq(aumSnap.before, aumSnap.after1, "AUM should not change");

    tvlSnap.before = tvlSnap.after1;
    aumSnap.before = aumSnap.after1;

    // Assuming Alice try deposit in the middle
    vm.deal(ALICE, 1 ether);
    motherload(address(usdc_e), ALICE, 10_000_000 * 1e6);
    addLiquidity(ALICE, usdc_e, 10_000_000 * 1e6, true);

    uint256 liquidityValue = ((10_000_000 * 1e22 * uint256(int256(ecoPyth2.getPriceUnsafe(bytes32("USDC")).price))) *
      9950) / 10000;

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);

    // Asserts
    assertEq(tvlSnap.before + liquidityValue, tvlSnap.after1, "TVL should increase by liquidity value");
    assertApproxEqAbs(
      aumSnap.before + liquidityValue,
      aumSnap.after1,
      0.16 * 1e30,
      "AUM should increase by liquidity value"
    );

    tvlSnap.before = tvlSnap.after1;
    aumSnap.before = aumSnap.after1;

    // Assuming Alice try to withdraw.
    uint256 hlpPrice = (aumSnap.before * 1e6) / hlp.totalSupply();
    uint256 estimateWithdrawValueE30 = (((5_000_000 ether * hlpPrice) / 1e6) * 9950) / 10000;
    unstakeHLP(ALICE, 5_000_000 ether);
    removeLiquidity(ALICE, usdc_e, 5_000_000 ether, true);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);

    // Asserts
    assertApproxEqAbs(
      tvlSnap.before - estimateWithdrawValueE30,
      tvlSnap.after1,
      25500 * 1e30,
      "TVL should decrease by withdraw value"
    );
    assertApproxEqAbs(
      aumSnap.before - estimateWithdrawValueE30,
      aumSnap.after1,
      25500 * 1e30,
      "AUM should decrease by withdraw value"
    );

    tvlSnap.before = tvlSnap.after1;
    aumSnap.before = aumSnap.after1;

    // Execute withdrawal orders
    gmxV2Keeper_executeWithdrawalOrder(GM_ETHUSDC_ASSET_ID, gmxOrderKey);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);

    assertEq(
      rebalanceHLPv2Service.getPendingWithdrawal(gmxOrderKey).market,
      address(0),
      "Withdrawal order should be deleted"
    );
    assertEq(vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity on hold should be 0");
    assertEq(vaultStorage.hlpLiquidity(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity should be 0");
    assertEq(vaultStorage.pullToken(address(gmETHUSD)), 0, "GM(ETH-USDC) pull token should be 0");
    assertEq(vaultStorage.pullToken(address(weth)), 0, "WETH pull token should be 0");
    assertEq(vaultStorage.pullToken(address(usdc)), 0, "USDC pull token should be 0");
    assertApproxEqAbs(tvlSnap.after1, tvlSnap.before, 5_000 * 1e30, "TVL should not change more than 5,000 USD");
    assertApproxEqAbs(aumSnap.after1, aumSnap.before, 5_000 * 1e30, "AUM should not change more than 5,000 USD");
  }

  function testCorrectness_WhenSomeoneJamInTheMiddle_DepositWithdrawCollateral() external {
    SnapshotUint256 memory tvlSnap;
    SnapshotUint256 memory aumSnap;
    SnapshotUint256 memory usdcTotalSnap;
    SnapshotUint256 memory usdcBalanceSnap;
    SnapshotUint256 memory wethTotalSnap;
    SnapshotUint256 memory wethBalanceSnap;

    tvlSnap.before = calculator.getHLPValueE30(false);
    aumSnap.before = calculator.getAUME30(false);

    // Create withdrawal orders
    bytes32 gmxOrderKey = rebalanceHLPv2_createWithdrawalOrder(GM_ETHUSDC_ASSET_ID, 8912412145575829437123, 0, 0);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);

    // Asserts
    assertEq(tvlSnap.before, tvlSnap.after1, "TVL should not change");
    assertEq(aumSnap.before, aumSnap.after1, "AUM should not change");

    tvlSnap.before = tvlSnap.after1;
    aumSnap.before = aumSnap.after1;
    usdcTotalSnap.before = vaultStorage.totalAmount(address(usdc_e));
    usdcBalanceSnap.before = usdc_e.balanceOf(address(vaultStorage));

    // Assuming Alice try deposit in the middle
    vm.deal(ALICE, 1 ether);
    motherload(address(usdc_e), ALICE, 10_000_000 * 1e6);
    depositCollateral(ALICE, 0, usdc_e, 10_000_000 * 1e6);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);
    usdcTotalSnap.after1 = vaultStorage.totalAmount(address(usdc_e));
    usdcBalanceSnap.after1 = usdc_e.balanceOf(address(vaultStorage));

    // Assert the following values are correct
    assertEq(tvlSnap.before, tvlSnap.after1, "TVL should not change");
    assertEq(aumSnap.before, aumSnap.after1, "AUM should not change");
    assertEq(
      usdcTotalSnap.before + 10_000_000 * 1e6,
      usdcTotalSnap.after1,
      "USDC.E total should increase by 10_000_000 USDC"
    );
    assertEq(
      usdcBalanceSnap.before + 10_000_000 * 1e6,
      usdcBalanceSnap.after1,
      "USDC.E balance should increase by 10_000_000 USDC"
    );
    assertEq(
      vaultStorage.traderBalances(ALICE, address(usdc_e)),
      10_000_000 * 1e6,
      "Alice's USDC.E balance should be 10_000_000 USDC"
    );

    tvlSnap.before = tvlSnap.after1;
    aumSnap.before = aumSnap.after1;
    usdcTotalSnap.before = usdcTotalSnap.after1;
    usdcBalanceSnap.before = usdcBalanceSnap.after1;

    withdrawCollateral(ALICE, 0, usdc_e, 10_000_000 * 1e6);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);
    usdcTotalSnap.after1 = vaultStorage.totalAmount(address(usdc_e));
    usdcBalanceSnap.after1 = usdc_e.balanceOf(address(vaultStorage));

    // Assert the following values are correct
    assertEq(tvlSnap.before, tvlSnap.after1, "TVL should not change");
    assertEq(aumSnap.before, aumSnap.after1, "AUM should not change");
    assertEq(
      usdcTotalSnap.before - 10_000_000 * 1e6,
      usdcTotalSnap.after1,
      "USDC.E total should decrease by 10_000_000 USDC"
    );
    assertEq(
      usdcBalanceSnap.before - 10_000_000 * 1e6,
      usdcBalanceSnap.after1,
      "USDC.E balance should decrease by 10_000_000 USDC"
    );
    assertEq(vaultStorage.traderBalances(ALICE, address(usdc_e)), 0, "Alice's USDC.E balance should be 0 USDC");

    tvlSnap.before = tvlSnap.after1;
    aumSnap.before = aumSnap.after1;
    wethTotalSnap.before = vaultStorage.totalAmount(address(weth));
    wethBalanceSnap.before = weth.balanceOf(address(vaultStorage));
    usdcTotalSnap.before = vaultStorage.totalAmount(address(usdc));
    usdcBalanceSnap.before = usdc.balanceOf(address(vaultStorage));

    // Execute withdrawal orders
    gmxV2Keeper_executeWithdrawalOrder(GM_ETHUSDC_ASSET_ID, gmxOrderKey);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);
    wethTotalSnap.after1 = vaultStorage.totalAmount(address(weth));
    wethBalanceSnap.after1 = weth.balanceOf(address(vaultStorage));
    usdcTotalSnap.after1 = vaultStorage.totalAmount(address(usdc));
    usdcBalanceSnap.after1 = usdc.balanceOf(address(vaultStorage));

    assertEq(
      rebalanceHLPv2Service.getPendingWithdrawal(gmxOrderKey).market,
      address(0),
      "Withdrawal order should be deleted"
    );
    assertEq(vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity on hold should be 0");
    assertEq(vaultStorage.hlpLiquidity(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity should be 0");
    assertEq(vaultStorage.pullToken(address(gmETHUSD)), 0, "GM(ETH-USDC) pull token should be 0");
    assertEq(vaultStorage.pullToken(address(weth)), 0, "WETH pull token should be 0");
    assertEq(vaultStorage.pullToken(address(usdc)), 0, "USDC pull token should be 0");
    assertApproxEqAbs(tvlSnap.after1, tvlSnap.before, 5_000 * 1e30, "TVL should not change more than 5,000 USD");
    assertApproxEqAbs(aumSnap.after1, aumSnap.before, 5_000 * 1e30, "AUM should not change more than 5,000 USD");
    assertEq(
      wethTotalSnap.before + 2522039333159539803,
      wethTotalSnap.after1,
      "WETH total should increase by 2522039333159539803"
    );
    assertEq(
      wethBalanceSnap.before + 2522039333159539803,
      wethBalanceSnap.after1,
      "WETH balance should increase by 2522039333159539803"
    );
    assertEq(wethTotalSnap.after1, wethBalanceSnap.after1, "WETH total should equal to WETH balance");
    assertEq(usdcTotalSnap.before + 4226796583, usdcTotalSnap.after1, "USDC total should increase by 4226796583");
    assertEq(usdcBalanceSnap.before + 4226796583, usdcBalanceSnap.after1, "USDC balance should increase by 4226796583");
    assertEq(usdcTotalSnap.after1, usdcBalanceSnap.after1, "USDC total should equal to USDC balance");
  }

  function testCorrectness_WhenSomeoneJamInTheMiddle_WhenTraderTakeProfitMoreThanHlpLiquidity() external {
    SnapshotUint256 memory tvlSnap;
    SnapshotUint256 memory aumSnap;
    SnapshotUint256 memory wethTotalSnap;
    SnapshotUint256 memory wethBalanceSnap;
    SnapshotUint256 memory wethLiquiditySnap;
    SnapshotUint256 memory usdcTotalSnap;
    SnapshotUint256 memory usdcBalanceSnap;
    SnapshotUint256 memory usdcLiquiditySnap;

    tvlSnap.before = calculator.getHLPValueE30(false);
    aumSnap.before = calculator.getAUME30(false);

    // Create withdrawal orders
    bytes32 gmxOrderKey = rebalanceHLPv2_createWithdrawalOrder(GM_ETHUSDC_ASSET_ID, 8912412145575829437123, 0, 0);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);

    // Asserts
    assertEq(tvlSnap.before, tvlSnap.after1, "TVL should not change");
    assertEq(aumSnap.before, aumSnap.after1, "AUM should not change");

    // Assuming Alice try deposit 1 WBTC as collateral and long BTC in the middle
    vm.deal(ALICE, 1 ether);
    motherload(address(wbtc), ALICE, 1 * 1e8);
    depositCollateral(ALICE, 0, wbtc, 1 * 1e8);
    marketBuy(ALICE, 0, 1, 750_000 * 1e30, address(weth));
    marketBuy(ALICE, 0, 1, 750_000 * 1e30, address(weth));
    // Assuming BTC moon to 150_000 USD and min profit passed
    vm.warp(block.timestamp + 60);
    MockEcoPyth(address(ecoPyth2)).overridePrice(bytes32("BTC"), 150_000 * 1e8);
    // Alice try to close position
    marketSell(ALICE, 0, 1, 750_000 * 1e30, address(weth));
    marketSell(ALICE, 0, 1, 750_000 * 1e30, address(weth));

    // Asserts
    assertEq(vaultStorage.hlpLiquidity(address(weth)), 0, "WETH liquidity should be 0");
    assertEq(
      vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)),
      8912412145575829437123,
      "GM(ETH-USDC) liquidity on hold should be 8912412145575829437123"
    );

    tvlSnap.before = calculator.getHLPValueE30(false);
    aumSnap.before = calculator.getAUME30(false);
    wethTotalSnap.before = vaultStorage.totalAmount(address(weth));
    wethBalanceSnap.before = weth.balanceOf(address(vaultStorage));
    wethLiquiditySnap.before = vaultStorage.hlpLiquidity(address(weth));
    usdcTotalSnap.before = vaultStorage.totalAmount(address(usdc));
    usdcBalanceSnap.before = usdc.balanceOf(address(vaultStorage));
    usdcLiquiditySnap.before = vaultStorage.hlpLiquidity(address(usdc));

    // Execute withdrawal orders
    gmxV2Keeper_executeWithdrawalOrder(GM_ETHUSDC_ASSET_ID, gmxOrderKey);

    tvlSnap.after1 = calculator.getHLPValueE30(false);
    aumSnap.after1 = calculator.getAUME30(false);
    wethTotalSnap.after1 = vaultStorage.totalAmount(address(weth));
    wethBalanceSnap.after1 = weth.balanceOf(address(vaultStorage));
    wethLiquiditySnap.after1 = vaultStorage.hlpLiquidity(address(weth));
    usdcTotalSnap.after1 = vaultStorage.totalAmount(address(usdc));
    usdcBalanceSnap.after1 = usdc.balanceOf(address(vaultStorage));
    usdcLiquiditySnap.after1 = vaultStorage.hlpLiquidity(address(usdc));

    // Asserts
    assertEq(
      rebalanceHLPv2Service.getPendingWithdrawal(gmxOrderKey).market,
      address(0),
      "Withdrawal order should be deleted"
    );
    assertEq(vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity on hold should be 0");
    assertEq(vaultStorage.hlpLiquidity(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity should be 0");
    assertEq(vaultStorage.pullToken(address(gmETHUSD)), 0, "GM(ETH-USDC) pull token should be 0");
    assertEq(vaultStorage.pullToken(address(weth)), 0, "WETH pull token should be 0");
    assertEq(vaultStorage.pullToken(address(usdc)), 0, "USDC pull token should be 0");
    assertApproxEqAbs(tvlSnap.after1, tvlSnap.before, 5_000 * 1e30, "TVL should not change more than 5,000 USD");
    assertApproxEqAbs(aumSnap.after1, aumSnap.before, 5_000 * 1e30, "AUM should not change more than 5,000 USD");
    assertEq(
      wethTotalSnap.before + 2522039519212270023,
      wethTotalSnap.after1,
      "WETH total should increase by 2522039519212270023"
    );
    assertEq(
      wethBalanceSnap.before + 2522039519212270023,
      wethBalanceSnap.after1,
      "WETH balance should increase by 2522039519212270023"
    );
    assertEq(
      wethLiquiditySnap.before + 2522039519212270023,
      wethLiquiditySnap.after1,
      "WETH liquidity should increase"
    );
    assertEq(wethTotalSnap.after1, wethBalanceSnap.after1, "WETH total should equal to WETH balance");
    assertEq(usdcTotalSnap.before + 4226796895, usdcTotalSnap.after1, "USDC total should increase by 4226796895");
    assertEq(usdcBalanceSnap.before + 4226796895, usdcBalanceSnap.after1, "USDC balance should increase by 4226796895");
    assertEq(usdcLiquiditySnap.before + 4226796895, usdcLiquiditySnap.after1, "USDC liquidity should increase");
    assertEq(usdcTotalSnap.after1, usdcBalanceSnap.after1, "USDC total should equal to USDC balance");
  }
}
