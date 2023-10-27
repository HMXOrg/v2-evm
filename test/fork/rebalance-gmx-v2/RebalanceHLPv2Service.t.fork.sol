// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { stdError } from "forge-std/StdError.sol";

/// HMX tests
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { MockEcoPyth } from "@hmx-test/mocks/MockEcoPyth.sol";
import { MockArbSys } from "@hmx-test/mocks/MockArbSys.sol";
import { MockGmxV2Oracle } from "@hmx-test/mocks/MockGmxV2Oracle.sol";

/// HMX
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";
import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

contract RebalanceHLPv2Service_ForkTest is ForkEnv, Cheats {
  bytes32 internal constant GM_WBTCUSDC_ASSET_ID = "GM(WBTC-USDC)";
  IRebalanceHLPv2Service rebalanceService;

  function setUp() external {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 143862285);

    // Mock ArbSys
    MockArbSys arbSys = new MockArbSys();
    vm.etch(0x0000000000000000000000000000000000000064, address(arbSys).code);

    // Mock GmxV2Oracle
    MockGmxV2Oracle mockGmxV2Oracle = new MockGmxV2Oracle();
    vm.etch(ForkEnv.gmxV2DepositHandler.oracle(), address(mockGmxV2Oracle).code);

    // Mock EcoPyth
    MockEcoPyth mockEcoPyth = new MockEcoPyth();
    vm.etch(address(ForkEnv.ecoPyth2), address(mockEcoPyth).code);

    rebalanceService = Deployer.deployRebalanceHLPv2Service(
      address(ForkEnv.proxyAdmin),
      address(ForkEnv.weth),
      address(ForkEnv.vaultStorage),
      address(ForkEnv.configStorage),
      address(ForkEnv.gmxV2ExchangeRouter),
      ForkEnv.gmxV2DepositVault,
      address(ForkEnv.gmxV2DepositHandler),
      10000
    );

    // Upgrade dependencies
    vm.startPrank(ForkEnv.proxyAdmin.owner());
    Deployer.upgrade("VaultStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.vaultStorage));
    Deployer.upgrade("Calculator", address(ForkEnv.proxyAdmin), address(ForkEnv.calculator));
    vm.stopPrank();

    // Setup
    vm.startPrank(ForkEnv.configStorage.owner());
    vaultStorage.setServiceExecutors(address(rebalanceService), true);
    vaultStorage.setServiceExecutors(address(this), true); // For testing pullToken
    configStorage.setServiceExecutor(address(rebalanceService), address(address(this)), true);
    vm.stopPrank();

    // Adding GM(WBTC-USDC) as a liquidity
    vm.startPrank(ForkEnv.multiSig);
    bytes32[] memory newAssetIds = new bytes32[](1);
    newAssetIds[0] = GM_WBTCUSDC_ASSET_ID;
    ForkEnv.ecoPyth2.insertAssetIds(newAssetIds);
    ForkEnv.pythAdapter.setConfig(GM_WBTCUSDC_ASSET_ID, GM_WBTCUSDC_ASSET_ID, false);
    ForkEnv.oracleMiddleware.setAssetPriceConfig(GM_WBTCUSDC_ASSET_ID, 0, 60 * 5, address(ForkEnv.pythAdapter));
    ForkEnv.configStorage.setAssetConfig(
      GM_WBTCUSDC_ASSET_ID,
      IConfigStorage.AssetConfig({
        assetId: GM_WBTCUSDC_ASSET_ID,
        tokenAddress: address(ForkEnv.gmxV2WbtcUsdcMarket),
        decimals: 18,
        isStableCoin: false
      })
    );
    vm.stopPrank();

    // Grant required roles
    vm.startPrank(ForkEnv.gmxV2Timelock);
    ForkEnv.gmxV2RoleStore.grantRole(address(this), keccak256(abi.encode("ORDER_KEEPER")));
    vm.stopPrank();

    vm.label(address(rebalanceService), "RebalanceHLPv2Service");
  }

  function doHlpDeposit(address user, IERC20 token, uint256 amount) internal {
    uint256 executionFee = 0.001 ether;
    vm.startPrank(user);
    vm.deal(user, 1 ether);
    motherload(address(token), user, amount);
    token.approve(address(ForkEnv.liquidityHandler), type(uint256).max);
    ForkEnv.liquidityHandler.createAddLiquidityOrder{ value: executionFee }(
      address(token),
      amount,
      0,
      executionFee,
      false
    );
    vm.stopPrank();
    /// Keeper comes and execute the deposit order
    vm.startPrank(ForkEnv.liquidityOrderExecutor);
    (
      bytes32[] memory priceData,
      bytes32[] memory publishedTimeData,
      uint256 minPublishedTime,
      bytes32 encodedVaas
    ) = MockEcoPyth(address(ForkEnv.ecoPyth2)).getLastestPriceUpdateData();
    ForkEnv.liquidityHandler.executeOrder(
      type(uint256).max,
      payable(ForkEnv.liquidityOrderExecutor),
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );
    vm.stopPrank();
  }

  function doHlpWithdraw(address user, uint256 amount, address receiveToken) internal {
    uint256 executionFee = 0.001 ether;
    vm.startPrank(user);
    ForkEnv.hlp.approve(address(ForkEnv.liquidityHandler), type(uint256).max);
    ForkEnv.hlpStaking.withdraw(amount);
    ForkEnv.liquidityHandler.createRemoveLiquidityOrder{ value: executionFee }(
      receiveToken,
      amount,
      0,
      executionFee,
      false
    );
    vm.stopPrank();
    /// Keeper comes and execute the deposit order
    vm.startPrank(ForkEnv.liquidityOrderExecutor);
    (
      bytes32[] memory priceData,
      bytes32[] memory publishedTimeData,
      uint256 minPublishedTime,
      bytes32 encodedVaas
    ) = MockEcoPyth(address(ForkEnv.ecoPyth2)).getLastestPriceUpdateData();
    ForkEnv.liquidityHandler.executeOrder(
      type(uint256).max,
      payable(ForkEnv.liquidityOrderExecutor),
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );
    vm.stopPrank();
  }

  function testCorrectness_WhenNoOneJamInTheMiddle() external {
    // Wrap small ETHs for execution fee
    uint256 executionFee = 0.001 ether;
    // Override GM(WBTC-USDC) price
    MockEcoPyth(address(ForkEnv.ecoPyth2)).overridePrice(GM_WBTCUSDC_ASSET_ID, 1.11967292 * 1e8);

    // Preps
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: address(ForkEnv.gmxV2WbtcUsdcMarket),
      longToken: address(ForkEnv.wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(ForkEnv.usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    uint256 beforeTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 beforeAum = ForkEnv.calculator.getAUME30(false);
    uint256 beforeTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    uint256 beforeWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

    // Wrap some ETHs for execution fee
    IWNative(address(ForkEnv.weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    ForkEnv.weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 afterAum = ForkEnv.calculator.getAUME30(false);
    uint256 afterTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    uint256 afterWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    // 3. 0.01 WBTC should be on-hold.
    // 4. pullToken should return zero.
    // 5. afterTotalWbtc should be decreased by 0.01 WBTC
    // 6. beforeWbtc should be 0.01 more than afterWbtc.
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");
    assertEq(0.01 * 1e8, ForkEnv.vaultStorage.hlpLiquidityOnHold(address(ForkEnv.wbtc)), "0.01 WBTC should be on-hold");
    assertEq(0, ForkEnv.vaultStorage.pullToken(address(ForkEnv.wbtc)), "pullToken should return zero");
    assertEq(afterTotalWbtc + 0.01 * 1e8, beforeTotalWbtc, "afterTotalWbtc should be decreased by 0.01 WBTC");
    assertEq(beforeWbtc - afterWbtc, 0.01 * 1e8, "wbtcBefore should be 0.01 more than wbtcAfter");

    // GMXv2 Keeper comes and execute the deposit order
    address[] memory realtimeFeedTokens = new address[](3);
    // Index token
    realtimeFeedTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd;
    // Long token
    realtimeFeedTokens[1] = address(ForkEnv.wbtc);
    // Short token
    realtimeFeedTokens[2] = address(ForkEnv.usdc);
    bytes[] memory realtimeFeedData = new bytes[](3);
    // Index token
    realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Long token
    realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Short token
    realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);

    beforeTvl = ForkEnv.calculator.getHLPValueE30(false);
    beforeAum = ForkEnv.calculator.getAUME30(false);
    uint256 beforeGmBtcTotal = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.gmxV2WbtcUsdcMarket));
    uint256 beforeGmBtc = ForkEnv.gmxV2WbtcUsdcMarket.balanceOf(address(ForkEnv.vaultStorage));
    beforeTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    beforeWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

    ForkEnv.gmxV2DepositHandler.executeDeposit(
      gmxDepositOrderKeys[0],
      IGmxV2Oracle.SetPricesParams({
        signerInfo: 0,
        tokens: new address[](0),
        compactedMinOracleBlockNumbers: new uint256[](0),
        compactedMaxOracleBlockNumbers: new uint256[](0),
        compactedOracleTimestamps: new uint256[](0),
        compactedDecimals: new uint256[](0),
        compactedMinPrices: new uint256[](0),
        compactedMinPricesIndexes: new uint256[](0),
        compactedMaxPrices: new uint256[](0),
        compactedMaxPricesIndexes: new uint256[](0),
        signatures: new bytes[](0),
        priceFeedTokens: new address[](0),
        realtimeFeedTokens: realtimeFeedTokens,
        realtimeFeedData: realtimeFeedData
      })
    );

    afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    afterAum = ForkEnv.calculator.getAUME30(false);
    uint256 afterGmBtcTotal = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.gmxV2WbtcUsdcMarket));
    uint256 afterGmBtc = ForkEnv.gmxV2WbtcUsdcMarket.balanceOf(address(ForkEnv.vaultStorage));
    afterTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    afterWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

    // Assert the following conditions:
    // 1. 0 WBTC should be on-hold.
    // 2. pullToken should return zero.
    // 3. totalWBtcAfter should decrease by 0.01 WBTC.
    // 4. wbtcBefore should remain the same.
    // 5. totalWbtcAfter should match wbtcBefore.
    // 6. gmBtcTotalAfter should more than gmBtcTotalBefore.
    // 7. gmBtcAfter should more than gmBtcBefore.
    // 8. gmBtcAfter should match with gmBtcTotalAfter.
    // 9. TVL should not change more than 0.01%
    // 10. AUM should not change more than 0.01%
    assertEq(0, ForkEnv.vaultStorage.hlpLiquidityOnHold(address(ForkEnv.wbtc)), "0 WBTC should be on-hold");
    assertEq(0, ForkEnv.vaultStorage.pullToken(address(ForkEnv.wbtc)), "pullToken should return zero");
    assertEq(afterTotalWbtc, beforeTotalWbtc - 0.01 * 1e8, "totalWbtcAfter should decrease by 0.01 WBTC");
    assertEq(beforeWbtc, afterWbtc, "wbtcBefore should remains the same");
    assertEq(afterWbtc, afterTotalWbtc, "total[WBTC] should match wbtcAfter");
    assertTrue(afterGmBtcTotal > beforeGmBtcTotal, "gmBtcTotalAfter should more than gmBtcTotalBefore");
    assertTrue(afterGmBtc > beforeGmBtc, "gmBtcAfter should more than gmBtcBefore");
    assertEq(afterGmBtc, afterGmBtcTotal, "gmBtcAfter should match with gmBtcTotalAfter");
    assertApproxEqRel(beforeTvl, afterTvl, 0.0001 ether, "tvl must remains the same");
    assertApproxEqRel(beforeAum, afterAum, 0.0001 ether, "aum must remains the same");
  }

  function testCorrectness_WhenSomeoneJamInTheMiddle() external {
    // Wrap small ETHs for execution fee
    uint256 executionFee = 0.001 ether;
    // Override GM(WBTC-USDC) price
    MockEcoPyth(address(ForkEnv.ecoPyth2)).overridePrice(GM_WBTCUSDC_ASSET_ID, 1.11967292 * 1e8);

    uint256 beforeTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 beforeAum = ForkEnv.calculator.getAUME30(false);

    // Preps
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: address(ForkEnv.gmxV2WbtcUsdcMarket),
      longToken: address(ForkEnv.wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(ForkEnv.usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    // Wrap some ETHs for execution fee
    IWNative(address(ForkEnv.weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    ForkEnv.weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 afterAum = ForkEnv.calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");

    beforeTvl = afterTvl;
    beforeAum = afterAum;

    /// Assuming Alice try to deposit in the middle
    doHlpDeposit(ALICE, ForkEnv.usdc_e, 10_000_000 * 1e6);
    uint256 liquidityValue = ((10_000_000 *
      1e22 *
      uint256(int256(ForkEnv.ecoPyth2.getPriceUnsafe(bytes32("USDC")).price))) * 9950) / 10000;

    afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    afterAum = ForkEnv.calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should increase by ~10,000,000 USD
    // 2. AUM should increase by ~10,000,000 USD
    assertEq(beforeTvl + liquidityValue, afterTvl, "tvl should increase by ~10,000,000 USD");
    assertApproxEqRel(beforeAum + liquidityValue, afterAum, 0.0001 ether, "aum should increase by ~10,000,000 USD");

    beforeTvl = afterTvl;
    beforeAum = afterAum;

    /// Assuming Alice try to withdraw.
    uint256 hlpPrice = (beforeAum * 1e6) / ForkEnv.hlp.totalSupply();
    uint256 estimateWithdrawValueE30 = (((5_000_000 ether * hlpPrice) / 1e6) * 9950) / 10000;
    doHlpWithdraw(ALICE, 5_000_000 ether, address(ForkEnv.usdc_e));

    afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    afterAum = ForkEnv.calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should decrease by ~5,000,000 USD
    // 2. AUM should decrease by ~5,000,000 USD
    assertApproxEqRel(
      beforeTvl - estimateWithdrawValueE30,
      afterTvl,
      0.001 ether,
      "tvl should decrease by ~5,000,000 USD"
    );
    assertApproxEqRel(
      beforeAum - estimateWithdrawValueE30,
      afterAum,
      0.001 ether,
      "aum should decrease by ~5,000,000 USD"
    );

    // GMXv2 Keeper comes and execute the deposit order
    address[] memory realtimeFeedTokens = new address[](3);
    // Index token
    realtimeFeedTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd;
    // Long token
    realtimeFeedTokens[1] = address(ForkEnv.wbtc);
    // Short token
    realtimeFeedTokens[2] = address(ForkEnv.usdc);
    bytes[] memory realtimeFeedData = new bytes[](3);
    // Index token
    realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Long token
    realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Short token
    realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);

    beforeTvl = ForkEnv.calculator.getHLPValueE30(false);
    beforeAum = ForkEnv.calculator.getAUME30(false);

    ForkEnv.gmxV2DepositHandler.executeDeposit(
      gmxDepositOrderKeys[0],
      IGmxV2Oracle.SetPricesParams({
        signerInfo: 0,
        tokens: new address[](0),
        compactedMinOracleBlockNumbers: new uint256[](0),
        compactedMaxOracleBlockNumbers: new uint256[](0),
        compactedOracleTimestamps: new uint256[](0),
        compactedDecimals: new uint256[](0),
        compactedMinPrices: new uint256[](0),
        compactedMinPricesIndexes: new uint256[](0),
        compactedMaxPrices: new uint256[](0),
        compactedMaxPricesIndexes: new uint256[](0),
        signatures: new bytes[](0),
        priceFeedTokens: new address[](0),
        realtimeFeedTokens: realtimeFeedTokens,
        realtimeFeedData: realtimeFeedData
      })
    );

    afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    afterAum = ForkEnv.calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. 0 WBTC should be on-hold.
    // 2. pullToken should return zero.
    // 3. TVL should not change more than 0.01%
    // 4. AUM should not change more than 0.01%
    assertEq(0, ForkEnv.vaultStorage.hlpLiquidityOnHold(address(ForkEnv.wbtc)), "0 WBTC should be on-hold");
    assertEq(ForkEnv.vaultStorage.pullToken(address(ForkEnv.wbtc)), 0, "pullToken should return zero");
    assertApproxEqRel(beforeTvl, afterTvl, 0.0001 ether, "tvl must remains the same");
    assertApproxEqRel(beforeAum, afterAum, 0.0001 ether, "aum must remains the same");
  }
}
