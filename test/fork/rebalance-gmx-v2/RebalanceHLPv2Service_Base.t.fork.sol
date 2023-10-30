// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// HMX
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

/// HMX Tests
import { ForkEnvWithActions } from "@hmx-test/fork/bases/ForkEnvWithActions.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { MockArbSys } from "@hmx-test/mocks/MockArbSys.sol";
import { MockGmxV2Oracle } from "@hmx-test/mocks/MockGmxV2Oracle.sol";

abstract contract RebalanceHLPv2Service_BaseForkTest is ForkEnvWithActions, Cheats {
  bytes32 internal constant GM_WBTCUSDC_ASSET_ID = "GM(WBTC-USDC)";
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

  function gmxV2ExecuteDepositOrder(bytes32 depositOrderId) internal {
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
