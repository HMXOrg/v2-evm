// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { console2 } from "forge-std/console2.sol";

/// HMX Test
import { RebalanceHLPv2Service_BaseForkTest } from "@hmx-test/fork/rebalance-gmx-v2/RebalanceHLPv2Service_Base.t.fork.sol";

contract RebalanceHLPv2Service_WithdrawalForkTest is RebalanceHLPv2Service_BaseForkTest {
  struct WithdrawalTestLocalVars {
    uint256 tvlBefore;
    uint256 aumBefore;
    uint256 gmEthBalanceBefore;
    uint256 gmEthTotalBefore;
    uint256 wethBalanceBefore;
    uint256 wethTotalBefore;
    uint256 usdcBalanceBefore;
    uint256 usdcTotalBefore;
    uint256 tvlAfter;
    uint256 aumAfter;
    uint256 gmEthBalanceAfter;
    uint256 gmEthTotalAfter;
    uint256 wethBalanceAfter;
    uint256 wethTotalAfter;
    uint256 usdcBalanceAfter;
    uint256 usdcTotalAfter;
  }

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
    WithdrawalTestLocalVars memory vars;
    vars.tvlBefore = calculator.getHLPValueE30(false);
    vars.aumBefore = calculator.getAUME30(false);
    vars.gmEthBalanceBefore = gmETHUSD.balanceOf(address(vaultStorage));
    vars.gmEthTotalBefore = vaultStorage.totalAmount(address(gmETHUSD));

    // Create withdrawal orders
    bytes32 gmxOrderKey = rebalanceHLPv2_createWithdrawalOrder(GM_ETHUSDC_ASSET_ID, 8912412145575829437123, 0, 0);

    vars.tvlAfter = calculator.getHLPValueE30(false);
    vars.aumAfter = calculator.getAUME30(false);
    vars.gmEthBalanceAfter = gmETHUSD.balanceOf(address(vaultStorage));
    vars.gmEthTotalAfter = vaultStorage.totalAmount(address(gmETHUSD));

    assertEq(
      vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)),
      8912412145575829437123,
      "GM(ETH-USDC) liquidity on hold should be 8912412145575829437123"
    );
    assertEq(vars.tvlAfter, vars.tvlBefore, "TVL should not change");
    assertEq(vars.aumAfter, vars.aumBefore, "AUM should not change");
    assertEq(vars.gmEthBalanceAfter, 0, "GM(ETH-USDC) balance should be 0");
    assertEq(vars.gmEthTotalAfter, vars.gmEthTotalBefore, "GM(ETH-USDC) total should not change");

    vars.tvlBefore = vars.tvlAfter;
    vars.aumBefore = vars.aumAfter;
    vars.gmEthBalanceBefore = vars.gmEthBalanceAfter;
    vars.gmEthTotalBefore = vars.gmEthTotalAfter;
    vars.wethBalanceBefore = weth.balanceOf(address(vaultStorage));
    vars.wethTotalBefore = vaultStorage.totalAmount(address(weth));
    vars.usdcBalanceBefore = usdc.balanceOf(address(vaultStorage));
    vars.usdcTotalBefore = vaultStorage.totalAmount(address(usdc));

    // Execute withdrawal orders
    gmxV2Keeper_executeWithdrawalOrder(GM_ETHUSDC_ASSET_ID, gmxOrderKey);

    vars.tvlAfter = calculator.getHLPValueE30(false);
    vars.aumAfter = calculator.getAUME30(false);
    vars.gmEthBalanceAfter = gmETHUSD.balanceOf(address(vaultStorage));
    vars.gmEthTotalAfter = vaultStorage.totalAmount(address(gmETHUSD));
    vars.wethBalanceAfter = weth.balanceOf(address(vaultStorage));
    vars.wethTotalAfter = vaultStorage.totalAmount(address(weth));
    vars.usdcBalanceAfter = usdc.balanceOf(address(vaultStorage));
    vars.usdcTotalAfter = vaultStorage.totalAmount(address(usdc));

    assertEq(
      rebalanceService.getWithdrawalHistory(gmxOrderKey).market,
      address(0),
      "Withdrawal order should be deleted"
    );
    assertEq(vaultStorage.hlpLiquidityOnHold(address(gmETHUSD)), 0, "GM(ETH-USDC) liquidity on hold should be 0");
    assertApproxEqAbs(vars.tvlAfter, vars.tvlBefore, 5_000 * 1e30, "TVL should not change more than 5,000 USD");
    assertApproxEqAbs(vars.aumAfter, vars.aumBefore, 5_000 * 1e30, "AUM should not change more than 5,000 USD");
    assertEq(vars.gmEthBalanceAfter, 0, "GM(ETH-USDC) balance should be 0");
    assertEq(vars.gmEthTotalAfter, 0, "GM(ETH-USDC) after executed total should be 0");
    assertEq(
      vars.wethBalanceBefore + 2522039333159539803,
      vars.wethBalanceAfter,
      "WETH balance should increase by 2522039333159539803"
    );
    assertEq(
      vars.wethTotalBefore + 2522039333159539803,
      vars.wethTotalAfter,
      "WETH total should increase by 2522039333159539803"
    );
    assertEq(vars.wethTotalAfter, vars.wethBalanceAfter, "WETH total should equal to WETH balance");
    assertEq(vars.usdcBalanceBefore + 4226796583, vars.usdcBalanceAfter, "USDC balance should increase by 4226796583");
    assertEq(vars.usdcTotalBefore + 4226796583, vars.usdcTotalAfter, "USDC total should increase by 4226796583");
    assertEq(vars.usdcTotalAfter, vars.usdcBalanceAfter, "USDC total should equal to USDC balance");
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
}
