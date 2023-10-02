// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { IExt01Handler } from "@hmx/handlers/interfaces/IExt01Handler.sol";

import "forge-std/console.sol";

contract TC40 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  function testCorrectness_TC40_TransferCollateralSubAccount_WETH() external {

    address _tokenAddress = address(weth);

    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    address[] memory accounts = new address[](1);
    accounts[0] = ALICE;
    uint8[] memory subAccountIds = new uint8[](1);

    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      // Mint liquidity for BOB
      usdc.mint(BOB, 100_000 * 1e6);

      // Mint collateral and gas for ALICE
      vm.deal(ALICE, 20 ether);
    }

    vm.warp(block.timestamp + 1);
    // BOB add liquidity
    addLiquidity(BOB, usdc, 100_000 * 1e6, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);

    // Deposit Collateral  
    vm.warp(block.timestamp + 1); 
    depositCollateral(ALICE, 0, ERC20(_tokenAddress), 10 ether, true);

    // Try transfer bad amount (0)
    vm.warp(block.timestamp + 1); 
    {
      vm.expectRevert(abi.encodeWithSignature("IExt01Handler_BadAmount()"));
      transferCollateralSubAccount(ALICE, 0, 1, _tokenAddress, 0);
    }

    // Try transfer too much amount
    vm.warp(block.timestamp + 1); 
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 0, 1, _tokenAddress, 30 ether);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 0;
      // Expect Revert from insufficient collateral
      vm.expectRevert();
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        false
      );
      vm.stopPrank();
    }

    // Try transfer to self
    vm.warp(block.timestamp + 1);
    {
      vm.expectRevert(abi.encodeWithSignature("IExt01Handler_SelfTransfer()"));
      transferCollateralSubAccount(ALICE, 0, 0, _tokenAddress, 10 ether);
    } 

    // Try transfer collateral btw. subAccount
    vm.warp(block.timestamp + 1); 
    {
      address _aliceSubAccount0 = getSubAccount(ALICE, 0);
      address _aliceSubAccount1 = getSubAccount(ALICE, 1);
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 0, 1, _tokenAddress, 10 ether);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 0;
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        true
      );
      vm.stopPrank();
      assertSubAccountTokenBalance(_aliceSubAccount0, _tokenAddress, false, 0);
      assertSubAccountTokenBalance(_aliceSubAccount1, _tokenAddress, true, 10 ether);
    }

    // Market order long
    vm.warp(block.timestamp + 1);
    {
      updatePriceData = new bytes[](3);
      tickPrices[1] = 99039; // WBTC tick price $20,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125

      marketBuy(ALICE, 1, wethMarketIndex, 100_000 * 1e30, _tokenAddress, tickPrices, publishTimeDiff, block.timestamp); 
    }

    // Try transfer collteral
    vm.warp(block.timestamp + 1);
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 1, 0, _tokenAddress, 5 ether);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 1;
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        true
      );
      vm.stopPrank();
    }

    // Try transfer collateral exceeds IMR
    vm.warp(block.timestamp + 1);
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 1, 0, _tokenAddress, 4.5 ether);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 1;
      // Expect Revert from withdraw balance below IMR
      vm.expectRevert();
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        false
      );
      vm.stopPrank();
    }

    // Close current position
    vm.warp(block.timestamp + 1);
    {
      marketSell(ALICE, 1, wethMarketIndex, 100_000 * 1e30, _tokenAddress, tickPrices, publishTimeDiff, block.timestamp);
    }

    // Transfer leftover collateral to subAccount 0
    vm.warp(block.timestamp + 1);
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 1, 0, _tokenAddress, 4.5 ether);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 1;
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        true
      );
      vm.stopPrank();
    }
  }
  function testCorrectness_TC40_TransferCollateralSubAccount_WBTC() external {
    wbtc.mint(ALICE, 0.5 * 1e8);
    _testTransferCollateralSubAccountERC20Helper(address(wbtc), 0.5 * 1e8, 100_000 * 1e30, 0.25 * 1e8, 0.2 * 1e8);
  }
  function testCorrectness_TC40_TransferCollateralSubAccount_USDC() external {
    usdc.mint(ALICE, 10_000 * 1e6);
    _testTransferCollateralSubAccountERC20Helper(address(usdc), 10_000 * 1e6, 100_000 * 1e30, 5_000 * 1e6, 4_000 * 1e6);
  }

  function _testTransferCollateralSubAccountERC20Helper(
    address _token,
    uint256 _deltAmount,
    uint256 _sizeDelta,
    uint256 _transfer1,
    uint256 _transfer2
  ) internal {

    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    address[] memory accounts = new address[](1);
    accounts[0] = ALICE;
    uint8[] memory subAccountIds = new uint8[](1);

    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      // Mint liquidity for BOB
      usdc.mint(BOB, 1_000_000 * 1e6);

      // Mint collateral and gas for ALICE
      vm.deal(ALICE, 10 ether);
    }

    vm.warp(block.timestamp + 1);
    // BOB add liquidity
    addLiquidity(BOB, usdc, 1_000_000 * 1e6, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);

    

    // Deposit Collateral  
    vm.warp(block.timestamp + 1); 
    depositCollateral(ALICE, 0, ERC20(_token), _deltAmount);

    // Try transfer bad amount (0)
    vm.warp(block.timestamp + 1); 
    {
      vm.expectRevert(abi.encodeWithSignature("IExt01Handler_BadAmount()"));
      transferCollateralSubAccount(ALICE, 0, 1, _token, 0);
    }

    // Try transfer too much amount
    vm.warp(block.timestamp + 1); 
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 0, 1, _token, 1e30);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 0;
      // Expect Revert from Insufficient Balance
      vm.expectRevert();
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        false
      );
      vm.stopPrank();
    }

    // Try transfer to self
    vm.warp(block.timestamp + 1);
    {
      vm.expectRevert(abi.encodeWithSignature("IExt01Handler_SelfTransfer()"));
      transferCollateralSubAccount(ALICE, 0, 0, _token, _deltAmount);
    } 

    // Try transfer collateral btw. subAccount
    vm.warp(block.timestamp + 1); 
    {
      // Get SubAccount address
      address _aliceSubAccount0 = getSubAccount(ALICE, 0);
      address _aliceSubAccount1 = getSubAccount(ALICE, 1);
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 0, 1, _token, _deltAmount);
      subAccountIds[0] = 0;
      vm.startPrank(EXT01_EXECUTOR);
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        true
      );
      vm.stopPrank();
      assertSubAccountTokenBalance(_aliceSubAccount0, _token, false, 0);
      assertSubAccountTokenBalance(_aliceSubAccount1, _token, true, _deltAmount);
    }

    // Market order long
    vm.warp(block.timestamp + 1);
    {
      updatePriceData = new bytes[](3);
      tickPrices[1] = 99039; // WBTC tick price $20,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125

      marketBuy(ALICE, 1, wethMarketIndex, _sizeDelta, _token, tickPrices, publishTimeDiff, block.timestamp);
    }

    // Try transfer collteral
    vm.warp(block.timestamp + 1);
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 1, 0, _token, _transfer1);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 1;
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        true
      );
      vm.stopPrank();
    }

    // Try transfer collateral exceeds IMR
    vm.warp(block.timestamp + 1);
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 1, 0, _token, _transfer2);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 1;
      // Expect Revert from withdraw balance below IMR
      vm.expectRevert();
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        false
      );
      vm.stopPrank();
    }

    // Close current position
    vm.warp(block.timestamp + 1);
    {
      marketSell(ALICE, 1, wethMarketIndex, _sizeDelta, _token, tickPrices, publishTimeDiff, block.timestamp);

    }

    // Transfer leftover collateral to subAccount 0
    vm.warp(block.timestamp + 1);
    {
      uint256[] memory _orderIndexes = transferCollateralSubAccount(ALICE, 1, 0, _token, _transfer2);
      vm.startPrank(EXT01_EXECUTOR);
      subAccountIds[0] = 1;
      ext01Handler.executeOrders(
        accounts,
        subAccountIds,
        _orderIndexes,
        payable(EXT01_EXECUTOR),
        _priceData,
        _publishTimeData,
        block.timestamp,
        "",
        true
      );
      vm.stopPrank();
    }
  }
}
