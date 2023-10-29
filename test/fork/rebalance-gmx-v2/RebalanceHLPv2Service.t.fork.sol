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
import { ForkEnvWithActions } from "@hmx-test/fork/bases/ForkEnvWithActions.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { MockEcoPyth } from "@hmx-test/mocks/MockEcoPyth.sol";
import { MockArbSys } from "@hmx-test/mocks/MockArbSys.sol";
import { MockGmxV2Oracle } from "@hmx-test/mocks/MockGmxV2Oracle.sol";

/// HMX
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";
import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

contract RebalanceHLPv2Service_ForkTest is ForkEnvWithActions, Cheats {
  bytes32 internal constant GM_WBTCUSDC_ASSET_ID = "GM(WBTC-USDC)";
  IRebalanceHLPv2Service rebalanceService;

  function setUp() external {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 143862285);

    // Mock ArbSys
    MockArbSys arbSys = new MockArbSys();
    vm.etch(0x0000000000000000000000000000000000000064, address(arbSys).code);

    // Mock GmxV2Oracle
    MockGmxV2Oracle mockGmxV2Oracle = new MockGmxV2Oracle();
    vm.etch(gmxV2DepositHandler.oracle(), address(mockGmxV2Oracle).code);

    // Mock EcoPyth
    makeEcoPythMockable();

    rebalanceService = Deployer.deployRebalanceHLPv2Service(
      address(proxyAdmin),
      address(weth),
      address(vaultStorage),
      address(configStorage),
      address(gmxV2ExchangeRouter),
      gmxV2DepositVault,
      address(gmxV2DepositHandler),
      10000
    );

    // Upgrade dependencies
    vm.startPrank(proxyAdmin.owner());
    Deployer.upgrade("VaultStorage", address(proxyAdmin), address(vaultStorage));
    Deployer.upgrade("Calculator", address(proxyAdmin), address(calculator));
    vm.stopPrank();

    // Setup
    vm.startPrank(configStorage.owner());
    vaultStorage.setServiceExecutors(address(rebalanceService), true);
    vaultStorage.setServiceExecutors(address(this), true); // For testing pullToken
    configStorage.setServiceExecutor(address(rebalanceService), address(address(this)), true);
    vm.stopPrank();

    // Adding GM(WBTC-USDC) as a liquidity
    vm.startPrank(multiSig);
    bytes32[] memory newAssetIds = new bytes32[](1);
    newAssetIds[0] = GM_WBTCUSDC_ASSET_ID;
    ecoPyth2.insertAssetIds(newAssetIds);
    pythAdapter.setConfig(GM_WBTCUSDC_ASSET_ID, GM_WBTCUSDC_ASSET_ID, false);
    oracleMiddleware.setAssetPriceConfig(GM_WBTCUSDC_ASSET_ID, 0, 60 * 5, address(pythAdapter));
    configStorage.setAssetConfig(
      GM_WBTCUSDC_ASSET_ID,
      IConfigStorage.AssetConfig({
        assetId: GM_WBTCUSDC_ASSET_ID,
        tokenAddress: address(gmxV2WbtcUsdcMarket),
        decimals: 18,
        isStableCoin: false
      })
    );
    vm.stopPrank();

    // Grant required roles
    vm.startPrank(gmxV2Timelock);
    gmxV2RoleStore.grantRole(address(this), keccak256(abi.encode("ORDER_KEEPER")));
    vm.stopPrank();

    vm.label(address(rebalanceService), "RebalanceHLPv2Service");
  }

  function testCorrectness_WhenNoOneJamInTheMiddle() external {
    // Wrap small ETHs for execution fee
    uint256 executionFee = 0.001 ether;
    // Override GM(WBTC-USDC) price
    MockEcoPyth(address(ecoPyth2)).overridePrice(GM_WBTCUSDC_ASSET_ID, 1.11967292 * 1e8);

    // Preps
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: address(gmxV2WbtcUsdcMarket),
      longToken: address(wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    uint256 beforeTvl = calculator.getHLPValueE30(false);
    uint256 beforeAum = calculator.getAUME30(false);
    uint256 beforeTotalWbtc = vaultStorage.totalAmount(address(wbtc));
    uint256 beforeWbtc = wbtc.balanceOf(address(vaultStorage));

    // Wrap some ETHs for execution fee
    IWNative(address(weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = calculator.getHLPValueE30(false);
    uint256 afterAum = calculator.getAUME30(false);
    uint256 afterTotalWbtc = vaultStorage.totalAmount(address(wbtc));
    uint256 afterWbtc = wbtc.balanceOf(address(vaultStorage));

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    // 3. 0.01 WBTC should be on-hold.
    // 4. pullToken should return zero.
    // 5. afterTotalWbtc should be the same as beforeTotalWbtc.
    // 6. beforeWbtc should be 0.01 more than afterWbtc.
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");
    assertEq(0.01 * 1e8, vaultStorage.hlpLiquidityOnHold(address(wbtc)), "0.01 WBTC should be on-hold");
    assertEq(0, vaultStorage.pullToken(address(wbtc)), "pullToken should return zero");
    assertEq(afterTotalWbtc, beforeTotalWbtc, "afterTotalWbtc should the same as before");
    assertEq(beforeWbtc - afterWbtc, 0.01 * 1e8, "wbtcBefore should be 0.01 more than wbtcAfter");

    // GMXv2 Keeper comes and execute the deposit order
    address[] memory realtimeFeedTokens = new address[](3);
    // Index token
    realtimeFeedTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd;
    // Long token
    realtimeFeedTokens[1] = address(wbtc);
    // Short token
    realtimeFeedTokens[2] = address(usdc);
    bytes[] memory realtimeFeedData = new bytes[](3);
    // Index token
    realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Long token
    realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Short token
    realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);

    beforeTvl = calculator.getHLPValueE30(false);
    beforeAum = calculator.getAUME30(false);
    uint256 beforeGmBtcTotal = vaultStorage.totalAmount(address(gmxV2WbtcUsdcMarket));
    uint256 beforeGmBtc = gmxV2WbtcUsdcMarket.balanceOf(address(vaultStorage));
    beforeTotalWbtc = vaultStorage.totalAmount(address(wbtc));
    beforeWbtc = wbtc.balanceOf(address(vaultStorage));

    gmxV2DepositHandler.executeDeposit(
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

    afterTvl = calculator.getHLPValueE30(false);
    afterAum = calculator.getAUME30(false);
    uint256 afterGmBtcTotal = vaultStorage.totalAmount(address(gmxV2WbtcUsdcMarket));
    uint256 afterGmBtc = gmxV2WbtcUsdcMarket.balanceOf(address(vaultStorage));
    afterTotalWbtc = vaultStorage.totalAmount(address(wbtc));
    afterWbtc = wbtc.balanceOf(address(vaultStorage));

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
    assertEq(0, vaultStorage.hlpLiquidityOnHold(address(wbtc)), "0 WBTC should be on-hold");
    assertEq(0, vaultStorage.pullToken(address(wbtc)), "pullToken should return zero");
    assertEq(afterTotalWbtc, beforeTotalWbtc - 0.01 * 1e8, "totalWbtcAfter should decrease by 0.01 WBTC");
    assertEq(beforeWbtc, afterWbtc, "wbtcBefore should remains the same");
    assertEq(afterWbtc, afterTotalWbtc, "total[WBTC] should match wbtcAfter");
    assertTrue(afterGmBtcTotal > beforeGmBtcTotal, "gmBtcTotalAfter should more than gmBtcTotalBefore");
    assertTrue(afterGmBtc > beforeGmBtc, "gmBtcAfter should more than gmBtcBefore");
    assertEq(afterGmBtc, afterGmBtcTotal, "gmBtcAfter should match with gmBtcTotalAfter");
    assertApproxEqRel(beforeTvl, afterTvl, 0.0001 ether, "tvl must remains the same");
    assertApproxEqRel(beforeAum, afterAum, 0.0001 ether, "aum must remains the same");
  }

  function testCorrectness_WhenSomeoneJamInTheMiddle_AddRemoveLiquidity() external {
    // Wrap small ETHs for execution fee
    uint256 executionFee = 0.001 ether;
    // Override GM(WBTC-USDC) price
    MockEcoPyth(address(ecoPyth2)).overridePrice(GM_WBTCUSDC_ASSET_ID, 1.11967292 * 1e8);

    uint256 beforeTvl = calculator.getHLPValueE30(false);
    uint256 beforeAum = calculator.getAUME30(false);

    // Preps
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: address(gmxV2WbtcUsdcMarket),
      longToken: address(wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    // Wrap some ETHs for execution fee
    IWNative(address(weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = calculator.getHLPValueE30(false);
    uint256 afterAum = calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");

    beforeTvl = afterTvl;
    beforeAum = afterAum;

    /// Assuming Alice try to deposit in the middle
    vm.deal(ALICE, 1 ether);
    motherload(address(usdc_e), ALICE, 10_000_000 * 1e6);
    addLiquidity(ALICE, usdc_e, 10_000_000 * 1e6, true);

    uint256 liquidityValue = ((10_000_000 * 1e22 * uint256(int256(ecoPyth2.getPriceUnsafe(bytes32("USDC")).price))) *
      9950) / 10000;

    afterTvl = calculator.getHLPValueE30(false);
    afterAum = calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should increase by ~10,000,000 USD
    // 2. AUM should increase by ~10,000,000 USD
    assertEq(beforeTvl + liquidityValue, afterTvl, "tvl should increase by ~10,000,000 USD");
    assertApproxEqRel(beforeAum + liquidityValue, afterAum, 0.0001 ether, "aum should increase by ~10,000,000 USD");

    beforeTvl = afterTvl;
    beforeAum = afterAum;

    /// Assuming Alice try to withdraw.
    uint256 hlpPrice = (beforeAum * 1e6) / hlp.totalSupply();
    uint256 estimateWithdrawValueE30 = (((5_000_000 ether * hlpPrice) / 1e6) * 9950) / 10000;
    unstakeHLP(ALICE, 5_000_000 ether);
    removeLiquidity(ALICE, usdc_e, 5_000_000 ether, true);

    afterTvl = calculator.getHLPValueE30(false);
    afterAum = calculator.getAUME30(false);

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
    realtimeFeedTokens[1] = address(wbtc);
    // Short token
    realtimeFeedTokens[2] = address(usdc);
    bytes[] memory realtimeFeedData = new bytes[](3);
    // Index token
    realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Long token
    realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Short token
    realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);

    beforeTvl = calculator.getHLPValueE30(false);
    beforeAum = calculator.getAUME30(false);

    gmxV2DepositHandler.executeDeposit(
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

    afterTvl = calculator.getHLPValueE30(false);
    afterAum = calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. 0 WBTC should be on-hold.
    // 2. pullToken should return zero.
    // 3. TVL should not change more than 0.01%
    // 4. AUM should not change more than 0.01%
    assertEq(0, vaultStorage.hlpLiquidityOnHold(address(wbtc)), "0 WBTC should be on-hold");
    assertEq(vaultStorage.pullToken(address(wbtc)), 0, "pullToken should return zero");
    assertApproxEqRel(beforeTvl, afterTvl, 0.0001 ether, "tvl should not change more than 0.01%");
    assertApproxEqRel(beforeAum, afterAum, 0.0001 ether, "aum should not change more than 0.01%");
  }

  function testCorrectness_WhenSomeoneJamInTheMiddle_DepositWithdrawCollateral() external {
    // Wrap small ETHs for execution fee
    uint256 executionFee = 0.001 ether;
    // Override GM(WBTC-USDC) price
    MockEcoPyth(address(ecoPyth2)).overridePrice(GM_WBTCUSDC_ASSET_ID, 1.11967292 * 1e8);

    uint256 beforeTvl = calculator.getHLPValueE30(false);
    uint256 beforeAum = calculator.getAUME30(false);

    // Preps
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: address(gmxV2WbtcUsdcMarket),
      longToken: address(wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    // Wrap some ETHs for execution fee
    IWNative(address(weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = calculator.getHLPValueE30(false);
    uint256 afterAum = calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");

    // Alice try to deposit 1 WBTC as collateral in the middle
    vm.startPrank(ALICE);
    motherload(address(wbtc), ALICE, 1 * 1e8);
    wbtc.approve(address(crossMarginHandler), type(uint256).max);
    crossMarginHandler.depositCollateral(0, address(wbtc), 1 * 1e8, false);
    vm.stopPrank();

    // Assert the following conditions:
    // 1. WBTC's total amount should 9.97066301
    // 2. WBTC's balance should 9.96066301s
    // 3. Alice's WBTC balance in HMX should be 1e8
    assertEq(vaultStorage.totalAmount(address(wbtc)), 9.97066301 * 1e8, "totalAmount should be 9.97066301 WBTC");
    assertEq(wbtc.balanceOf(address(vaultStorage)), 9.96066301 * 1e8, "balance should be 9.96066301 WBTC");
    assertEq(vaultStorage.traderBalances(ALICE, address(wbtc)), 1 * 1e8, "Alice's WBTC balance should be 1e8");

    // Alice try withdraw 1 WBTC as collateral in the middle
    vm.startPrank(ALICE);
    vm.deal(ALICE, 1 ether);
    crossMarginHandler.createWithdrawCollateralOrder{ value: executionFee }(
      0,
      address(wbtc),
      1 * 1e8,
      executionFee,
      false
    );
    vm.stopPrank();
    // Keeper comes and execute the deposit order
    vm.startPrank(crossMarginOrderExecutor);
    (
      bytes32[] memory priceData,
      bytes32[] memory publishedTimeData,
      uint256 minPublishedTime,
      bytes32 encodedVaas
    ) = MockEcoPyth(address(ecoPyth2)).getLastestPriceUpdateData();
    crossMarginHandler.executeOrder(
      type(uint256).max,
      payable(crossMarginHandler),
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );
    vm.stopPrank();

    // Assert the following conditions:
    // 1. WBTC's total amount should 8.97066301
    // 2. WBTC's balance should 8.96066301s
    // 3. Alice's WBTC balance in HMX should be 0
    // 4. Alice's WBTC balance should be 1e8
    assertEq(vaultStorage.totalAmount(address(wbtc)), 8.97066301 * 1e8, "totalAmount should be 8.97066301 WBTC");
    assertEq(wbtc.balanceOf(address(vaultStorage)), 8.96066301 * 1e8, "balance should be 8.96066301 WBTC");
    assertEq(vaultStorage.traderBalances(ALICE, address(wbtc)), 0, "Alice's WBTC balance should be 0");
    assertEq(wbtc.balanceOf(ALICE), 1 * 1e8, "Alice's WBTC balance should be 1e8 (not in HMX)");

    // GMXv2 Keeper comes and execute the deposit order
    address[] memory realtimeFeedTokens = new address[](3);
    // Index token
    realtimeFeedTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd;
    // Long token
    realtimeFeedTokens[1] = address(wbtc);
    // Short token
    realtimeFeedTokens[2] = address(usdc);
    bytes[] memory realtimeFeedData = new bytes[](3);
    // Index token
    realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Long token
    realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Short token
    realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);

    beforeTvl = calculator.getHLPValueE30(false);
    beforeAum = calculator.getAUME30(false);

    gmxV2DepositHandler.executeDeposit(
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

    afterTvl = calculator.getHLPValueE30(false);
    afterAum = calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. 0 WBTC should be on-hold.
    // 2. pullToken should return zero.
    // 3. TVL should not change more than 0.01%
    // 4. AUM should not change more than 0.01%
    assertEq(0, vaultStorage.hlpLiquidityOnHold(address(wbtc)), "0 WBTC should be on-hold");
    assertEq(vaultStorage.pullToken(address(wbtc)), 0, "pullToken should return zero");
    assertApproxEqRel(beforeTvl, afterTvl, 0.0001 ether, "tvl should not change more than 0.01%");
    assertApproxEqRel(beforeAum, afterAum, 0.0001 ether, "aum should not change more than 0.01%");
  }

  function testCorrectness_WhenSomeoneJamInTheMiddle_WhenTraderTakeProfitMoreThanHlpLiquidity() external {
    // Some liquidity is on-hold, but trader try to take profit more than available liquidity.
    // This should be reverted with underflow.
    // Wrap small ETHs for execution fee
    uint256 executionFee = 0.001 ether;
    // Override GM(WBTC-USDC) price
    MockEcoPyth(address(ecoPyth2)).overridePrice(GM_WBTCUSDC_ASSET_ID, 1.11967292 * 1e8);

    uint256 beforeTvl = calculator.getHLPValueE30(false);
    uint256 beforeAum = calculator.getAUME30(false);
    uint256 initialHmxBtcBalance = wbtc.balanceOf(address(vaultStorage));

    // Preps
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: address(gmxV2WbtcUsdcMarket),
      longToken: address(wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    // Wrap some ETHs for execution fee
    IWNative(address(weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = calculator.getHLPValueE30(false);
    uint256 afterAum = calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");

    // Alice try to deposit 1 WBTC as collateral and long ETH in the middle
    vm.deal(ALICE, 1 ether);
    motherload(address(wbtc), ALICE, 1 * 1e8);
    depositCollateral(ALICE, 0, wbtc, 1 * 1e8);
    marketBuy(ALICE, 0, 0, 750_000 * 1e30, address(wbtc));
    marketBuy(ALICE, 0, 0, 750_000 * 1e30, address(wbtc));
    // Assuming ETH moon to 20_000 USD and min profit passed
    vm.warp(block.timestamp + 60);
    MockEcoPyth(address(ecoPyth2)).overridePrice(bytes32("ETH"), 30_000 * 1e8);
    // Alice try to close position
    marketSell(ALICE, 0, 0, 750_000 * 1e30, address(wbtc));
    marketSell(ALICE, 0, 1, 750_000 * 1e30, address(wbtc));

    // Assert the following conditions:
    // 1. HLP's WBTC liquidity should be drained.
    // 2. HLP's WBTC liquidity on-hold should be 0.01 * 1e8.
    // 3. HMX actual WBTC balance should be initialHmxBtcBalance + 1e8 - 0.01 * 1e8.
    assertEq(vaultStorage.hlpLiquidity(address(wbtc)), 0, "HLP liquidity should be drained after Alice take profit");
    assertEq(vaultStorage.hlpLiquidityOnHold(address(wbtc)), 0.01 * 1e8, "0.01 WBTC should be on-hold");
    assertEq(
      wbtc.balanceOf(address(vaultStorage)),
      initialHmxBtcBalance + 1e8 - 0.01 * 1e8,
      "HMX WBTC balance should correct"
    );

    uint256 aliceWbtcBalanceBefore = vaultStorage.traderBalances(ALICE, address(wbtc));
    motherload(address(wbtc), ALICE, 1 * 1e8);
    depositCollateral(ALICE, 0, wbtc, 1 * 1e8);
    uint256 aliceWbtcBalanceAfter = vaultStorage.traderBalances(ALICE, address(wbtc));

    // Assert the following conditions:
    // 1. Alice's WBTC balance in HMX should increase by 1e8
    // 2. HMX actual WBTC balance should be initialHmxBtcBalance + 2e8 - 0.01 * 1e8.
    assertEq(aliceWbtcBalanceAfter, aliceWbtcBalanceBefore + 1 * 1e8, "Alice's WBTC balance should increase by 1e8");
    assertEq(
      wbtc.balanceOf(address(vaultStorage)),
      initialHmxBtcBalance + 2e8 - 0.01 * 1e8,
      "HMX WBTC balance should correct"
    );

    // GMXv2 Keeper comes and execute the deposit order
    address[] memory realtimeFeedTokens = new address[](3);
    // Index token
    realtimeFeedTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd;
    // Long token
    realtimeFeedTokens[1] = address(wbtc);
    // Short token
    realtimeFeedTokens[2] = address(usdc);
    bytes[] memory realtimeFeedData = new bytes[](3);
    // Index token
    realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Long token
    realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Short token
    realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);

    beforeTvl = calculator.getHLPValueE30(false);
    beforeAum = calculator.getAUME30(false);
    uint256 gmBtcLiquidityBefore = vaultStorage.hlpLiquidity(address(gmxV2WbtcUsdcMarket));

    gmxV2DepositHandler.executeDeposit(
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

    afterTvl = calculator.getHLPValueE30(false);
    afterAum = calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. 0 WBTC should be on-hold.
    // 2. pullToken should return zero.
    // 3. TVL should not change more than 0.01%
    // 4. AUM should not change more than 0.01%
    // 5. GM(BTC-USDC) liquidity should increase
    assertEq(0, vaultStorage.hlpLiquidityOnHold(address(wbtc)), "0 WBTC should be on-hold");
    assertEq(vaultStorage.pullToken(address(wbtc)), 0, "pullToken should return zero");
    assertApproxEqRel(beforeTvl, afterTvl, 0.0001 ether, "tvl should not change more than 0.01%");
    assertApproxEqRel(beforeAum, afterAum, 0.0001 ether, "aum should not change more than 0.01%");
    assertTrue(
      vaultStorage.hlpLiquidity(address(gmxV2WbtcUsdcMarket)) > gmBtcLiquidityBefore,
      "GM(BTC-USDC) liquidity should increase"
    );
  }
}
