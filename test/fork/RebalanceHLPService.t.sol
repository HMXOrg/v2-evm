// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import "forge-std/console.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IRebalanceHLPHandler } from "@hmx/handlers/interfaces/IRebalanceHLPHandler.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract RebalanceHLPService_Test is ForkEnv {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  uint24[] internal publishTimeDiffs;

  uint256 fixedBlock = 121867415;
  int24[] tickPrices;

  function setUp() public {
    tickPrices = new int24[](3);
    // USDC Price
    tickPrices[0] = 0;
    // ETH Price
    tickPrices[1] = 73926;

    publishTimeDiffs = new uint24[](3);
    publishTimeDiffs[0] = 0;
    publishTimeDiffs[1] = 0;

    deal(address(weth), address(vaultStorage), 100 ether);
    deal(address(usdc_e), address(vaultStorage), 10000 * 1e6);
    deal(address(arb), address(vaultStorage), 100 ether);
    deal(address(wstEth), address(vaultStorage), 100 ether);

    vm.startPrank(address(tradeService));

    vaultStorage.pullToken(address(weth));
    vaultStorage.addHLPLiquidity(address(weth), 100 ether);

    vaultStorage.pullToken(address(usdc_e));
    vaultStorage.addHLPLiquidity(address(usdc_e), 10000 * 1e6);

    vaultStorage.pullToken(address(arb));
    vaultStorage.addHLPLiquidity(address(arb), 100 ether);

    vaultStorage.pullToken(address(wstEth));
    vaultStorage.addHLPLiquidity(address(wstEth), 100 ether);
    vm.stopPrank();
  }

  function testCorrectness_Rebalance_ReinvestSuccess() external {
    vm.roll(fixedBlock);
    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](2);
    uint256 usdcAmount = 1000 * 1e6;
    uint256 wethAmount = 10 * 1e18;

    params[0] = IRebalanceHLPService.AddGlpParams(address(usdc_e), address(0), usdcAmount, 990 * 1e6, 100);
    params[1] = IRebalanceHLPService.AddGlpParams(address(weth), address(0), wethAmount, 95 * 1e16, 100);

    uint256 usdcBefore = vaultStorage.hlpLiquidity(address(usdc_e));
    uint256 wethBefore = vaultStorage.hlpLiquidity(address(weth));
    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));

    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);

    uint256 receivedGlp = rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );

    // USDC
    assertEq(vaultStorage.hlpLiquidity(address(usdc_e)), usdcBefore - usdcAmount);
    assertEq(vaultStorage.hlpLiquidity(address(usdc_e)), vaultStorage.totalAmount(address(usdc_e)));
    // WETH
    assertEq(vaultStorage.hlpLiquidity(address(usdc_e)), wethBefore - wethAmount);
    assertEq(vaultStorage.hlpLiquidity(address(weth)), vaultStorage.totalAmount(address(weth)));
    // sGLP
    assertEq(receivedGlp, vaultStorage.hlpLiquidity(address(sglp)) - sGlpBefore);

    // make sure that the allowance is zero
    assertEq(IERC20Upgradeable(address(usdc_e)).allowance(address(rebalanceHLPService), address(glpManager)), 0);
    assertEq(IERC20Upgradeable(address(weth)).allowance(address(rebalanceHLPService), address(glpManager)), 0);
  }

  function testCorrectness_Rebalance_WithdrawSuccess() external {
    vm.roll(110369564);

    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](2);
    params[0] = IRebalanceHLPService.AddGlpParams(address(usdc_e), address(0), 1000 * 1e6, 990 * 1e6, 100);
    params[1] = IRebalanceHLPService.AddGlpParams(address(weth), address(0), 1 * 1e18, 95 * 1e16, 100);

    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
    rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );

    // setup sGLP in vault

    IRebalanceHLPService.WithdrawGlpParams[] memory _params = new IRebalanceHLPService.WithdrawGlpParams[](2);
    _params[0] = IRebalanceHLPService.WithdrawGlpParams(address(usdc_e), 15 * 1e18, 0);
    _params[1] = IRebalanceHLPService.WithdrawGlpParams(address(weth), 15 * 1e18, 0);

    uint256 usdcBalanceBefore = vaultStorage.totalAmount(address(usdc_e));
    uint256 wethBalanceBefore = vaultStorage.totalAmount(address(weth));

    uint256 sglpBefore = vaultStorage.hlpLiquidity(address(sglp));
    uint256 usdcHlpBefore = vaultStorage.hlpLiquidity(address(usdc_e));
    uint256 wethHlpBefore = vaultStorage.hlpLiquidity(address(weth));

    bytes32[] memory _priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory _publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);

    IRebalanceHLPService.WithdrawGlpResult[] memory result = rebalanceHLPHandler.withdrawGlp(
      _params,
      _priceUpdateData,
      _publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );

    uint256 usdcBalanceAfter = vaultStorage.totalAmount(address(usdc_e));
    uint256 wethBalanceAfter = vaultStorage.totalAmount(address(weth));

    uint256 sglpAfter = vaultStorage.hlpLiquidity(address(sglp));
    uint256 usdcHlpAfter = vaultStorage.hlpLiquidity(address(usdc_e));
    uint256 wethHlpAfter = vaultStorage.hlpLiquidity(address(weth));

    assertTrue(usdcBalanceAfter > usdcBalanceBefore);
    assertTrue(wethBalanceAfter > wethBalanceBefore);

    assertTrue(usdcHlpAfter > usdcHlpBefore);
    assertTrue(wethHlpAfter > wethHlpBefore);

    assertEq(usdcBalanceAfter - usdcBalanceBefore, result[0].amount);
    assertEq(wethBalanceAfter - wethBalanceBefore, result[1].amount);

    assertEq(sglpBefore - sglpAfter, 15 * 1e18 * 2);

    // make sure that the allowance is zero
    assertEq(usdc_e.allowance(address(rebalanceHLPService), address(glpManager)), 0);
    assertEq(weth.allowance(address(rebalanceHLPService), address(glpManager)), 0);

    assertEq(block.number, 110369564);
  }

  function testRevert_Rebalance_EmptyParams() external {
    IRebalanceHLPService.AddGlpParams[] memory params;
    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
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
    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
    uint256 usdcAmount = 100_000 * 1e6;
    vm.expectRevert(IRebalanceHLPService.RebalanceHLPService_InvalidTokenAmount.selector);
    params[0] = IRebalanceHLPService.AddGlpParams(address(usdc_e), address(0), usdcAmount, 99_000 * 1e6, 10_000);
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
    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
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
    params[0] = IRebalanceHLPService.WithdrawGlpParams(address(usdc_e), 1e30, 0);
    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);

    vm.expectRevert(IRebalanceHLPService.RebalanceHLPService_InvalidTokenAmount.selector);
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
    params[0] = IRebalanceHLPService.AddGlpParams(address(weth), address(0), 90 * 1e18, 88 * 1e18, 100 * 1e18);

    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);

    vm.expectRevert(IRebalanceHLPService.RebalanceHLPService_HlpTvlDropExceedMin.selector);
    rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );
  }

  function testCorrectness_Rebalance_SwapReinvestSuccess() external {
    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](2);
    uint256 arbAmount = 10 * 1e18;

    params[0] = IRebalanceHLPService.AddGlpParams(
      address(arb), // to be swapped
      address(weth), // to be received
      arbAmount,
      95 * 1e16,
      100
    );
    params[1] = IRebalanceHLPService.AddGlpParams(
      address(wstEth), // to be swapped
      address(weth), // to be received
      arbAmount,
      95 * 1e16,
      100
    );

    uint256 arbBefore = vaultStorage.hlpLiquidity(address(arb));
    uint256 wstEthBefore = vaultStorage.hlpLiquidity(address(wstEth));
    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));

    bytes32[] memory priceUpdateData = ecoPyth2.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);

    uint256 receivedGlp = rebalanceHLPHandler.addGlp(
      params,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("encodeVass")
    );

    // address(arb)
    assertEq(vaultStorage.hlpLiquidity(address(arb)), vaultStorage.totalAmount(address(arb)));
    assertEq(vaultStorage.hlpLiquidity(address(arb)), arbBefore - arbAmount);
    // address(wstEth)
    assertEq(vaultStorage.hlpLiquidity(address(wstEth)), vaultStorage.totalAmount(address(wstEth)));
    assertEq(vaultStorage.hlpLiquidity(address(wstEth)), wstEthBefore - arbAmount);
    // sGLP
    assertEq(receivedGlp, vaultStorage.hlpLiquidity(address(sglp)) - sGlpBefore);

    // make sure that the allowance is zero
    assertEq(weth.allowance(address(rebalanceHLPService), address(glpManager)), 0);
  }
}
