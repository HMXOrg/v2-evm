// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { console2 } from "forge-std/console2.sol";

/// HMX Test
import { RebalanceHLPv2Service_BaseForkTest } from "@hmx-test/fork/rebalance-gmx-v2/RebalanceHLPv2Service_Base.t.fork.sol";

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

  function testCorrectness_WhenNoOneJamInTheMiddle() external {
    uint256 tvlBefore = calculator.getHLPValueE30(false);
    uint256 aumBefore = calculator.getAUME30(false);
    uint256 gmEthBalanceBefore = gmxV2EthUsdcMarket.balanceOf(address(vaultStorage));
    uint256 gmEthTotalBefore = vaultStorage.totalAmount(address(gmxV2EthUsdcMarket));

    // Create withdrawal orders
    bytes32 gmxOrderKey = rebalanceHLPv2_createWithdrawalOrder(GM_ETHUSDC_ASSET_ID, 8912412145575829437123, 0, 0);

    uint256 tvlAfter = calculator.getHLPValueE30(false);
    uint256 aumAfter = calculator.getAUME30(false);
    uint256 gmEthBalanceAfter = gmxV2EthUsdcMarket.balanceOf(address(vaultStorage));
    uint256 gmEthTotalAfter = vaultStorage.totalAmount(address(gmxV2EthUsdcMarket));

    assertEq(
      vaultStorage.hlpLiquidityOnHold(address(gmxV2EthUsdcMarket)),
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
    gmEthBalanceAfter = gmxV2EthUsdcMarket.balanceOf(address(vaultStorage));
    gmEthTotalAfter = vaultStorage.totalAmount(address(gmxV2EthUsdcMarket));

    assertEq(
      vaultStorage.hlpLiquidityOnHold(address(gmxV2EthUsdcMarket)),
      0,
      "GM(ETH-USDC) liquidity on hold should be 0"
    );
    assertApproxEqAbs(tvlAfter, tvlBefore, 5_000 * 1e30, "TVL should not change more than 5,000 USD");
    assertApproxEqAbs(aumAfter, aumBefore, 5_000 * 1e30, "AUM should not change more than 5,000 USD");
    assertEq(gmEthBalanceAfter, 0, "GM(ETH-USDC) balance should be 0");
    assertEq(gmEthTotalAfter, 0, "GM(ETH-USDC) after executed total should be 0");
  }
}
