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
    console2.log(vaultStorage.hlpLiquidity(address(weth)));
    bytes32 gmxV2OrderKey = rebalanceHLPv2_createDepositOrder(GM_ETHUSDC_ASSET_ID, 60 ether, 0 ether, 0);
    assertEq(vaultStorage.hlpLiquidityOnHold(address(weth)), 60 ether, "WETH liquidity on hold should be 60 ETH");
    gmxV2Keeper_executeDepositOrder(GM_ETHUSDC_ASSET_ID, gmxV2OrderKey);
    assertEq(vaultStorage.hlpLiquidityOnHold(address(weth)), 0, "WETH liquidity on hold should be 0 ETH");
  }

  function testCorrectness_WhenNoOneJamInTheMiddle() external {}
}
