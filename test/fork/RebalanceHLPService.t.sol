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
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { Smoke_Base } from "@hmx-test/fork/smoke-test/Smoke_Base.t.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

contract RebalanceHLPService_Test is Smoke_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  uint24[] internal publishTimeDiffs;

  uint256 fixedBlock = 121867415;
  int24[] tickPrices;

  uint256 _minPublishTime;
  bytes32[] _priceUpdateCalldata;
  bytes32[] _publishTimeUpdateCalldata;

  function setUp() public override {
    super.setUp();

    tickPrices = new int24[](3);
    // USDC Price
    tickPrices[0] = 0;
    // ETH Price
    tickPrices[1] = 73926;

    publishTimeDiffs = new uint24[](3);
    publishTimeDiffs[0] = 0;
    publishTimeDiffs[1] = 0;

    vm.startPrank(rebalanceHLPHandler.owner());
    rebalanceHLPHandler.setWhitelistExecutor(address(this), true);
    vm.stopPrank();

    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();
    (_minPublishTime, _priceUpdateCalldata, _publishTimeUpdateCalldata) = ForkEnv.ecoPythBuilder.build(data);
  }

  function testCorrectness_Rebalance_Success() external {
    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](2);
    uint256 usdcAmount = HMXLib.min(vaultStorage.hlpLiquidity(address(usdc_e)), 1000 * 1e6);
    uint256 wethAmount = HMXLib.min(vaultStorage.hlpLiquidity(address(weth)), 0.1 * 1e18);

    params[0] = IRebalanceHLPService.AddGlpParams(address(usdc_e), address(0), usdcAmount, 990 * 1e6, 100);
    params[1] = IRebalanceHLPService.AddGlpParams(address(weth), address(0), wethAmount, 95 * 1e16, 100);

    uint256 usdcBefore = vaultStorage.hlpLiquidity(address(usdc_e));
    uint256 wethBefore = vaultStorage.hlpLiquidity(address(weth));
    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));

    uint256 receivedGlp = rebalanceHLPHandler.addGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("encodeVass")
    );

    // USDC
    assertEq(vaultStorage.hlpLiquidity(address(usdc_e)), usdcBefore - usdcAmount, "usdc");
    // WETH
    assertEq(vaultStorage.hlpLiquidity(address(weth)), wethBefore - wethAmount, "weth");
    // sGLP
    assertEq(receivedGlp, vaultStorage.hlpLiquidity(address(sglp)) - sGlpBefore, "sglp");

    // // make sure that the allowance is zero
    assertEq(IERC20Upgradeable(address(usdc_e)).allowance(address(rebalanceHLPService), address(glpManager)), 0);
    assertEq(IERC20Upgradeable(address(weth)).allowance(address(rebalanceHLPService), address(glpManager)), 0);
  }

  function testCorrectness_Rebalance_WithdrawSuccess() external {
    vm.roll(110369564);

    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](2);
    params[0] = IRebalanceHLPService.AddGlpParams(address(usdc_e), address(0), 1000 * 1e6, 990 * 1e6, 100);
    params[1] = IRebalanceHLPService.AddGlpParams(address(weth), address(0), 1 * 1e18, 95 * 1e16, 100);

    rebalanceHLPHandler.addGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
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

    IRebalanceHLPService.WithdrawGlpResult[] memory result = rebalanceHLPHandler.withdrawGlp(
      _params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
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
    vm.expectRevert(IRebalanceHLPHandler.RebalanceHLPHandler_ParamsIsEmpty.selector);
    rebalanceHLPHandler.addGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_OverAmount() external {
    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](1);
    uint256 usdcAmount = vaultStorage.hlpLiquidity(address(usdc_e)) + 1;
    vm.expectRevert(IRebalanceHLPService.RebalanceHLPService_InvalidTokenAmount.selector);
    params[0] = IRebalanceHLPService.AddGlpParams(address(usdc_e), address(0), usdcAmount, 99_000 * 1e6, 10_000);
    rebalanceHLPHandler.addGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_NotWhitelisted() external {
    IRebalanceHLPService.AddGlpParams[] memory params;
    vm.expectRevert(IRebalanceHLPHandler.RebalanceHLPHandler_NotWhiteListed.selector);
    vm.prank(ALICE);
    rebalanceHLPHandler.addGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_WithdrawExceedingAmount() external {
    IRebalanceHLPService.WithdrawGlpParams[] memory params = new IRebalanceHLPService.WithdrawGlpParams[](1);
    params[0] = IRebalanceHLPService.WithdrawGlpParams(address(usdc_e), 1e30, 0);

    vm.expectRevert(IRebalanceHLPService.RebalanceHLPService_InvalidTokenAmount.selector);
    rebalanceHLPHandler.withdrawGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("encodeVass")
    );
  }

  function testRevert_Rebalance_NegativeTotalHLPValue() external {
    vm.startPrank(rebalanceHLPService.owner());
    rebalanceHLPService.setMinHLPValueLossBPS(1);
    vm.stopPrank();

    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](4);
    params[0] = IRebalanceHLPService.AddGlpParams(address(usdc_e), address(0), 1_700_000 * 1e6, 0, 0);
    params[1] = IRebalanceHLPService.AddGlpParams(
      address(weth),
      address(0),
      vaultStorage.hlpLiquidity(address(weth)),
      0,
      0
    );
    params[2] = IRebalanceHLPService.AddGlpParams(
      address(wbtc),
      address(0),
      vaultStorage.hlpLiquidity(address(wbtc)),
      0,
      0
    );
    params[3] = IRebalanceHLPService.AddGlpParams(
      address(usdt),
      address(0),
      vaultStorage.hlpLiquidity(address(usdt)),
      0,
      0
    );

    vm.expectRevert(IRebalanceHLPService.RebalanceHLPService_HlpTvlDropExceedMin.selector);
    rebalanceHLPHandler.addGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("encodeVass")
    );
  }

  function testCorrectness_Rebalance_SwapReinvestSuccess() external {
    IRebalanceHLPService.AddGlpParams[] memory params = new IRebalanceHLPService.AddGlpParams[](1);
    uint256 arbAmount = 10 * 1e18;

    params[0] = IRebalanceHLPService.AddGlpParams(
      address(arb), // to be swapped
      address(weth), // to be received
      arbAmount,
      95 * 1e16,
      100
    );

    uint256 arbBefore = vaultStorage.hlpLiquidity(address(arb));
    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));

    uint256 receivedGlp = rebalanceHLPHandler.addGlp(
      params,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("encodeVass")
    );

    // ARB
    assertEq(vaultStorage.hlpLiquidity(address(arb)), arbBefore - arbAmount);
    // sGLP
    assertEq(receivedGlp, vaultStorage.hlpLiquidity(address(sglp)) - sGlpBefore);

    // make sure that the allowance is zero
    assertEq(weth.allowance(address(rebalanceHLPService), address(glpManager)), 0);
  }
}
