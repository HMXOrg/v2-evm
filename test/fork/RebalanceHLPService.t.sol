// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import "forge-std/console.sol";
import { GlpStrategy_Base } from "./GlpStrategy_Base.t.fork.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IRebalanceHLPHandler } from "@hmx/handlers/interfaces/IRebalanceHLPHandler.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract RebalanceHLPSerivce is GlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  uint24[] internal publishTimeDiffs;

  function setUp() public override {
    super.setUp();

    tickPrices = new int24[](3);
    // USDC Price
    tickPrices[0] = 0;
    // ETH Price
    tickPrices[1] = 75446;

    publishTimeDiffs = new uint24[](3);
    publishTimeDiffs[0] = 0;
    publishTimeDiffs[1] = 0;

    deal(wethAddress, address(vaultStorage), 100 ether);
    vaultStorage.pullToken(wethAddress);
    vaultStorage.addHLPLiquidity(wethAddress, 100 ether);
    deal(usdcAddress, address(vaultStorage), 10000 * 1e6);
    vaultStorage.pullToken(usdcAddress);
    vaultStorage.addHLPLiquidity(usdcAddress, 10000 * 1e6);
  }

  function testCorrectness_Rebalance_ReinvestSuccess() external {
    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](2);
    uint256 usdcAmount = 1000 * 1e6;
    uint256 wethAmount = 10 * 1e18;

    params[0] = IRebalanceHLPService.AddGlpParams(usdcAddress, usdcAmount, 990 * 1e6, 100);
    params[1] = IRebalanceHLPService.AddGlpParams(wethAddress, wethAmount, 95 * 1e16, 100);

    uint256 usdcBefore = vaultStorage.hlpLiquidity(usdcAddress);
    uint256 wethBefore = vaultStorage.hlpLiquidity(wethAddress);
    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));

    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);

    uint256 receivedGlp = rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );

    // USDC
    assertEq(vaultStorage.hlpLiquidity(usdcAddress), usdcBefore - usdcAmount);
    assertEq(vaultStorage.hlpLiquidity(usdcAddress), vaultStorage.totalAmount(usdcAddress));
    // WETH
    assertEq(vaultStorage.hlpLiquidity(wethAddress), wethBefore - wethAmount);
    assertEq(vaultStorage.hlpLiquidity(wethAddress), vaultStorage.totalAmount(wethAddress));
    // sGLP
    assertEq(receivedGlp, vaultStorage.hlpLiquidity(address(sglp)) - sGlpBefore);

    // make sure that the allowance is zero
    assertEq(IERC20Upgradeable(usdcAddress).allowance(address(rebalanceHLPService), address(glpManager)), 0);
    assertEq(IERC20Upgradeable(wethAddress).allowance(address(rebalanceHLPService), address(glpManager)), 0);
  }

  function testCorrectness_Rebalance_WithdrawSuccess() external {
    vm.roll(110369564);

    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](2);
    params[0] = IRebalanceHLPService.AddGlpParams(usdcAddress, 1000 * 1e6, 990 * 1e6, 100);
    params[1] = IRebalanceHLPService.AddGlpParams(wethAddress, 1 * 1e18, 95 * 1e16, 100);

    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);
    rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );

    // setup sGLP in vault

    IRebalanceHLPService.WithdrawGlpParams[] memory _params = new IRebalanceHLPService.WithdrawGlpParams[](2);
    _params[0] = IRebalanceHLPService.WithdrawGlpParams(usdcAddress, 15 * 1e18, 0);
    _params[1] = IRebalanceHLPService.WithdrawGlpParams(wethAddress, 15 * 1e18, 0);

    uint256 usdcBalanceBefore = vaultStorage.totalAmount(usdcAddress);
    uint256 wethBalanceBefore = vaultStorage.totalAmount(wethAddress);

    uint256 sglpBefore = vaultStorage.hlpLiquidity(address(sglp));
    uint256 usdcHlpBefore = vaultStorage.hlpLiquidity(usdcAddress);
    uint256 wethHlpBefore = vaultStorage.hlpLiquidity(wethAddress);

    bytes32[] memory _priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory _publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);

    IRebalanceHLPService.WithdrawGlpResult[] memory result = rebalanceHLPHandler.withdrawGlp(
      _params,
      _priceUpdateData,
      _publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );

    uint256 usdcBalanceAfter = vaultStorage.totalAmount(usdcAddress);
    uint256 wethBalanceAfter = vaultStorage.totalAmount(wethAddress);

    uint256 sglpAfter = vaultStorage.hlpLiquidity(address(sglp));
    uint256 usdcHlpAfter = vaultStorage.hlpLiquidity(usdcAddress);
    uint256 wethHlpAfter = vaultStorage.hlpLiquidity(wethAddress);

    assertTrue(usdcBalanceAfter > usdcBalanceBefore);
    assertTrue(wethBalanceAfter > wethBalanceBefore);

    assertTrue(usdcHlpAfter > usdcHlpBefore);
    assertTrue(wethHlpAfter > wethHlpBefore);

    assertEq(usdcBalanceAfter - usdcBalanceBefore, result[0].amount);
    assertEq(wethBalanceAfter - wethBalanceBefore, result[1].amount);

    assertEq(sglpBefore - sglpAfter, 15 * 1e18 * 2);

    // make sure that the allowance is zero
    assertEq(IERC20Upgradeable(usdcAddress).allowance(address(rebalanceHLPService), address(glpManager)), 0);
    assertEq(IERC20Upgradeable(wethAddress).allowance(address(rebalanceHLPService), address(glpManager)), 0);

    assertEq(block.number, 110369564);
  }

  function testRevert_Rebalance_EmptyParams() external {
    IRebalanceHLPService.AddGlpParams[] memory params;
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);
    vm.expectRevert(IRebalanceHLPHandler.RebalanceHLPHandler_ParamsIsEmpty.selector);
    rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_OverAmount() external {
    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](1);
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);
    uint256 usdcAmount = 100_000 * 1e6;
    vm.expectRevert(IRebalanceHLPHandler.RebalanceHLPHandler_InvalidTokenAmount.selector);
    params[0] = IRebalanceHLPService.AddGlpParams(usdcAddress, usdcAmount, 99_000 * 1e6, 10_000);
    rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_NotWhitelisted() external {
    IRebalanceHLPService.AddGlpParams[] memory params;
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);
    vm.expectRevert(IRebalanceHLPHandler.RebalanceHLPHandler_NotWhiteListed.selector);
    vm.prank(ALICE);
    rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_WithdrawExceedingAmount() external {
    IRebalanceHLPService.WithdrawGlpParams[] memory params = new IRebalanceHLPService.WithdrawGlpParams[](1);
    params[0] = IRebalanceHLPService.WithdrawGlpParams(usdcAddress, 1e30, 0);
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);

    vm.expectRevert(IRebalanceHLPHandler.RebalanceHLPHandler_InvalidTokenAmount.selector);
    rebalanceHLPHandler.withdrawGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_NegativeTotalHLPValue() external {
    tickPrices = new int24[](3);
    tickPrices[0] = 0;
    tickPrices[1] = 76966;

    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](1);
    params[0] = IRebalanceHLPService.AddGlpParams(wethAddress, 90 * 1e18, 88 * 1e18, 100);

    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiffs);

    vm.expectRevert(IRebalanceHLPHandler.RebalanceHLPHandler_HlpTvlDropExceedMin.selector);
    rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );
  }
}
