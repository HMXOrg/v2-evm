// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console } from "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TC01 is BaseIntTest_WithActions {
  function testCorrectness_AddAndRemoveLiquiditySuccess() external {
    // T0: Initialized state

    // WBTC = 20k
    // ALICE NEED 10k in terms of WBTC = 10000 /20000 * 10**8  = 5e7
    uint256 _amount = (10_000 * (10 ** configStorage.getAssetTokenDecimal(address(wbtc)))) / 20_000;
    uint256 _executionFee = 0.01 ether;

    // mint 0.5 btc and give 0.01 gas
    vm.deal(ALICE, 1 ether);
    wbtc.mint(ALICE, _amount);

    // Alice Create Order And Executor Execute Order

    // T1: As a Liquidity, Alice adds 10,000 USD(GLP)
    addLiquidity(
      ALICE,
      ERC20(address(wbtc)),
      _amount,
      _executionFee, // minExecutionFee
      initialPriceFeedDatas,
      0
    );

    uint256 _amountAlice = plpV2.balanceOf(ALICE);
    removeLiquidity(
      ALICE,
      ERC20(address(wbtc)),
      _amountAlice,
      _executionFee, // minExecutionFee
      initialPriceFeedDatas,
      1
    );

    // T2: Alice withdraws 100,000 USD with PLP
    // T3: Alice withdraws GLP 100 USD
    // T5: As a Liquidity, Bob adds 100 USD(GLP)
    // T6: Alice max withdraws 9,900 USD PLP in pools
  }
}
