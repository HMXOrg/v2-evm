// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { LimitTradeHelper } from "@hmx/helpers/LimitTradeHelper.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract TC02_03 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;
  LimitTradeHelper internal limitTradeHelper;

  // TC02.3 - trader could take profit both long and short position
  // This integration test will test the step min profit duration during increase and decrease position
  function testCorrectness_TC0201_TradeWithLargerPositionThanLimitScenario() external {
    limitTradeHelper = new LimitTradeHelper(address(configStorage), address(perpStorage));

    // Set min profit duration for ETHUSD and BTCUSD as 300 seconds
    uint256[] memory marketIndexes = new uint256[](1);
    marketIndexes[0] = 0;
    uint256[] memory minProfitDurations = new uint256[](1);
    minProfitDurations[0] = 300;
    configStorage.setMinProfitDurations(marketIndexes, minProfitDurations);

    IConfigStorage.StepMinProfitDuration[] memory steps = new IConfigStorage.StepMinProfitDuration[](3);
    steps[0] = IConfigStorage.StepMinProfitDuration({
      fromSize: 0,
      toSize: 10_000 * 1e30,
      minProfitDuration: 1 minutes
    });
    steps[1] = IConfigStorage.StepMinProfitDuration({
      fromSize: 10_000 * 1e30,
      toSize: 100_000 * 1e30,
      minProfitDuration: 3 minutes
    });
    steps[2] = IConfigStorage.StepMinProfitDuration({
      fromSize: 100_000 * 1e30,
      toSize: type(uint256).max,
      minProfitDuration: 10 minutes
    });
    configStorage.addStepMinProfitDuration(steps);

    // prepare token for wallet
    // mint native token
    vm.deal(BOB, 1 ether);
    vm.deal(ALICE, 1 ether);
    vm.deal(FEEVER, 1 ether);

    // mint BTC
    wbtc.mint(ALICE, 100 * 1e8);
    wbtc.mint(BOB, 100 * 1e8);

    // warp to block timestamp 1000
    vm.warp(1000);

    // T1: BOB provide liquidity as WBTC 1 token
    // note: price has no changed0
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);

    // time passed for 60 seconds
    skip(60);

    // T2: alice deposit 1 BTC @$20,000
    depositCollateral(ALICE, 0, wbtc, 1 * 1e8);

    // time passed for 60 seconds
    skip(60);

    // T3: ALICE market buy weth with 300 USD at price 1574.87614416 USD
    //     Then Alice should has Long Position in WETH market
    tickPrices[0] = 73623; // ETHUSD = 1574.87614416
    marketBuy(ALICE, 0, wethMarketIndex, 300 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    bytes32 _positionId = keccak256(abi.encodePacked(ALICE, wethMarketIndex));
    IPerpStorage.Position memory _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 300 * 1e30);

    // T4: ALICE market buy weth with 100 USD at price 1622.83582907 USD under Min Profit Duration
    // This would fail because min profit duration is still active and the position is profitable.
    tickPrices[0] = 73923; // ETHUSD = 1622.83582907
    marketBuy(ALICE, 0, wethMarketIndex, 100 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    _positionId = keccak256(abi.encodePacked(ALICE, wethMarketIndex));
    _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 300 * 1e30);

    // time passed for 2 minutes
    skip(2 minutes);

    // T5: ALICE market buy weth with 100 USD at price 1622.83582907 USD
    // This would pass as the min profit duration has already expired.
    // But ALICE position will be under min profit duration again for 3 minutes in the second step
    tickPrices[0] = 73923; // ETHUSD = 1622.83582907
    marketBuy(ALICE, 0, wethMarketIndex, 100 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    _positionId = keccak256(abi.encodePacked(ALICE, wethMarketIndex));
    _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 400 * 1e30);

    // time passed for 2 minutes
    skip(2 minutes);

    // T5: ALICE market buy weth with 10,000 USD at price 1622.83582907 USD
    // This would pass as the min profit duration has already expired.
    // But ALICE position will be under min profit duration again for 3 minutes in the second step
    tickPrices[0] = 73923; // ETHUSD = 1622.83582907
    marketBuy(ALICE, 0, wethMarketIndex, 10_000 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    _positionId = keccak256(abi.encodePacked(ALICE, wethMarketIndex));
    _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 400 * 1e30);

    // time passed for 2 minutes
    skip(2 minutes);

    // T6: ALICE will not be able to interact with the position due to min profit duration of 3 minutes
    marketBuy(ALICE, 0, wethMarketIndex, 10_000 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    _positionId = keccak256(abi.encodePacked(ALICE, wethMarketIndex));
    _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 10_400 * 1e30);

    // T6: ALICE market sell weth with 100 USD at price 1622.83582907 USD under Min Profit Duration
    // This would fail because min profit duration is still active and the position is profitable.
    tickPrices[0] = 73923; // ETHUSD = 1622.83582907
    marketSell(ALICE, 0, wethMarketIndex, 100 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    _positionId = keccak256(abi.encodePacked(ALICE, wethMarketIndex));
    _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 10_200 * 1e30);

    // // T7: ALICE market sell weth with 100 USD at price 1528.33381234 USD under Min Profit Duration
    // // This should be possible because the position is not profitable.
    // tickPrices[0] = 73323; // ETHUSD = 1528.33381234
    // marketSell(ALICE, 0, wethMarketIndex, 100 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    // _positionId = keccak256(abi.encodePacked(ALICE, wethMarketIndex));
    // _position = perpStorage.getPositionById(_positionId);
    // assertEq(_position.positionSizeE30, 300 * 1e30);
  }
}
