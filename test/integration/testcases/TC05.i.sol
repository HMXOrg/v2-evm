// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console } from "forge-std/console.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

contract TC05 is BaseIntTest_WithActions {
  function setUp() public {
    // vm.warp(block.timestamp + 1);
    // uint8 SUB_ACCOUNT_ID = 1;
    // address SUB_ACCOUNT = getSubAccount(ALICE, SUB_ACCOUNT_ID);
    // Make LP contains some liquidity
    // depositCollateral(AL)
  }

  function testIntegration_TC05() external {
    bytes[] memory priceData = new bytes[](0);
    vm.deal(BOB, 10 ether); //deal with out of gas
    usdt.mint(BOB, 1_000_000 * 1e6);
    addLiquidity(BOB, usdt, 1_000_000 * 1e6, 1 ether, priceData);

    usdt.mint(ALICE, 1_000_000 * 1e6);
    depositCollateral(ALICE, 0, usdt, 14_000 * 1e6);

    address ALICE_SUB_ACCOUNT = getSubAccount(ALICE, 0);
    bytes32 ALICE_POSITION_ID = getPositionId(ALICE_SUB_ACCOUNT, 0);

    // console.log(calculator.getFreeCollateral(ALICE, 0, 0));
    console.log("buy");
    marketBuy(ALICE, 0, 0, 1_000_000 * 1e30, address(usdt), priceData);

    {
      // IPerpStorage.Position memory position = perpStorage.getPositionById(ALICE_POSITION_ID);
      // console.log("price", position.avgEntryPriceE30);
      // int256 equity = calculator.getEquity(ALICE, 0, 0);
      // console.log(uint256(equity));
      // console.log("collateral", uint256(calculator.getCollateralValue(ALICE, 0, 0)));
      // console.log("pnl", uint256(calculator.getUnrealizedPnl(ALICE, 0, 0)));
      // console.log("mmr", uint256(calculator.getMMR(ALICE)));
    }

    vm.warp(block.timestamp + (20 * MINUTE));
    //  Set Price for ETHUSD to 1,550 USD
    bytes32[] memory _assetIds = new bytes32[](6);
    _assetIds[0] = wethAssetId;
    _assetIds[1] = usdcAssetId;
    _assetIds[2] = daiAssetId;
    _assetIds[3] = wbtcAssetId;
    _assetIds[4] = usdtAssetId;
    _assetIds[5] = gmxAssetId;
    int64[] memory _prices = new int64[](6);
    _prices[0] = 1_400;
    _prices[1] = 1;
    _prices[2] = 1;
    _prices[3] = 20_000;
    _prices[4] = 1;
    _prices[5] = 1;
    setPrices(_assetIds, _prices);

    {
      // IPerpStorage.Position memory position = perpStorage.getPositionById(ALICE_POSITION_ID);
      // console.log("price", position.avgEntryPriceE30);
      // console.log("equity", uint256(calculator.getEquity(ALICE, 0, 0)));
      // console.log("collateral", uint256(calculator.getCollateralValue(ALICE, 0, 0)));
      // console.log("pnl", uint256(-calculator.getUnrealizedPnl(ALICE, 0, 0)));
      // console.log("mmr", uint256(calculator.getMMR(ALICE)));
    }

    liquidate(ALICE, priceData);
  }
}
