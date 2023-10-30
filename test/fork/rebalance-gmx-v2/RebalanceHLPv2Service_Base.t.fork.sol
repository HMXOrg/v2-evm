// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// HMX
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";

/// HMX Tests
import { ForkEnvWithActions } from "@hmx-test/fork/bases/ForkEnvWithActions.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { String } from "@hmx-test/libs/String.sol";
import { MockArbSys } from "@hmx-test/mocks/MockArbSys.sol";
import { MockGmxV2Oracle } from "@hmx-test/mocks/MockGmxV2Oracle.sol";

abstract contract RebalanceHLPv2Service_BaseForkTest is ForkEnvWithActions, Cheats {
  bytes32 internal constant GM_WBTCUSDC_ASSET_ID = "GM(WBTC-USDC)";
  bytes32 internal constant GM_ETHUSDC_ASSET_ID = "GM(ETH-USDC)";

  struct GmMarketConfig {
    address marketAddress;
    address longToken;
    address shortToken;
  }
  mapping(bytes32 gmMarketAssetId => GmMarketConfig config) internal gmMarketConfigs;

  IRebalanceHLPv2Service rebalanceService;

  function setUp() public virtual {
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
      address(gmxV2WithdrawalHandler)
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

    // Adding GM(WBTC-USDC) and GM(ETH-USDC) as a liquidity
    vm.startPrank(multiSig);
    bytes32[] memory newAssetIds = new bytes32[](2);
    newAssetIds[0] = GM_WBTCUSDC_ASSET_ID;
    newAssetIds[1] = GM_ETHUSDC_ASSET_ID;
    ecoPyth2.insertAssetIds(newAssetIds);
    pythAdapter.setConfig(GM_WBTCUSDC_ASSET_ID, GM_WBTCUSDC_ASSET_ID, false);
    pythAdapter.setConfig(GM_ETHUSDC_ASSET_ID, GM_ETHUSDC_ASSET_ID, false);
    oracleMiddleware.setAssetPriceConfig(GM_WBTCUSDC_ASSET_ID, 0, 60 * 5, address(pythAdapter));
    oracleMiddleware.setAssetPriceConfig(GM_ETHUSDC_ASSET_ID, 0, 60 * 5, address(pythAdapter));
    configStorage.setAssetConfig(
      GM_WBTCUSDC_ASSET_ID,
      IConfigStorage.AssetConfig({
        assetId: GM_WBTCUSDC_ASSET_ID,
        tokenAddress: address(gmxV2WbtcUsdcMarket),
        decimals: 18,
        isStableCoin: false
      })
    );
    configStorage.setAssetConfig(
      GM_ETHUSDC_ASSET_ID,
      IConfigStorage.AssetConfig({
        assetId: GM_ETHUSDC_ASSET_ID,
        tokenAddress: address(gmxV2EthUsdcMarket),
        decimals: 18,
        isStableCoin: false
      })
    );
    vm.stopPrank();

    // Grant required roles
    vm.startPrank(gmxV2Timelock);
    gmxV2RoleStore.grantRole(address(this), keccak256(abi.encode("ORDER_KEEPER")));
    vm.stopPrank();

    // Setup GM(WBTC-USDC) config
    gmMarketConfigs[GM_WBTCUSDC_ASSET_ID] = GmMarketConfig({
      marketAddress: address(gmxV2WbtcUsdcMarket),
      longToken: address(wbtc),
      shortToken: address(usdc)
    });
    // Setup GM(ETH-USDC) config
    gmMarketConfigs[GM_ETHUSDC_ASSET_ID] = GmMarketConfig({
      marketAddress: address(gmxV2EthUsdcMarket),
      longToken: address(weth),
      shortToken: address(usdc)
    });

    vm.label(address(rebalanceService), "RebalanceHLPv2Service");
  }

  function rebalanceHLPv2_createDepositOrder(
    bytes32 market,
    uint256 longTokenAmount,
    uint256 shortTokenAmount,
    uint256 minMarketTokens,
    string memory errSignature
  ) internal returns (bytes32) {
    // Preps
    uint256 executionFee = 0.001 ether;
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: gmMarketConfigs[market].marketAddress,
      longToken: gmMarketConfigs[market].longToken,
      longTokenAmount: longTokenAmount,
      shortToken: gmMarketConfigs[market].shortToken,
      shortTokenAmount: shortTokenAmount,
      minMarketTokens: minMarketTokens,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    // Wrap some ETHs for execution fee
    IWNative(address(weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    if (!String.isEmpty(errSignature)) {
      vm.expectRevert(abi.encodeWithSignature(errSignature));
    }
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.createDepositOrders(depositParams, executionFee);

    if (gmxDepositOrderKeys.length == 0) {
      return bytes32(0);
    }

    return gmxDepositOrderKeys[0];
  }

  function rebalanceHLPv2_createDepositOrder(
    bytes32 market,
    uint256 longTokenAmount,
    uint256 shortTokenAmount,
    uint256 minMarketTokens
  ) internal returns (bytes32) {
    return rebalanceHLPv2_createDepositOrder(market, longTokenAmount, shortTokenAmount, minMarketTokens, "");
  }

  function gmxV2Keeper_executeDepositOrder(bytes32 market, bytes32 depositOrderId) internal {
    address[] memory realtimeFeedTokens;
    bytes[] memory realtimeFeedData;

    if (market == GM_WBTCUSDC_ASSET_ID) {
      // For BTCUSDC, we need to set the price for 0x479 as well as wbtc and usdc
      realtimeFeedTokens = new address[](3);
      realtimeFeedData = new bytes[](3);
      // Index token
      realtimeFeedTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd;
      // Long token
      realtimeFeedTokens[1] = address(wbtc);
      // Short token
      realtimeFeedTokens[2] = address(usdc);
      // Index token
      realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
      // Long token
      realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
      // Short token
      realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);
    } else if (market == GM_ETHUSDC_ASSET_ID) {
      // For ETHUSDC, only ETH and USDC are needed
      realtimeFeedTokens = new address[](2);
      realtimeFeedData = new bytes[](2);
      // Long token
      realtimeFeedTokens[0] = address(weth);
      // Short token
      realtimeFeedTokens[1] = address(usdc);
      // Long token
      realtimeFeedData[0] = abi.encode(1784642714660000, 1784736100000000);
      // Short token
      realtimeFeedData[1] = abi.encode(999896170000000000000000, 1000040390000000000000000);
    }

    gmxV2DepositHandler.executeDeposit(
      depositOrderId,
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
  }
}
