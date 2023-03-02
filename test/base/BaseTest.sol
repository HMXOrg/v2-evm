// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { TestBase } from "forge-std/Base.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

import { Deployment } from "../../script/Deployment.s.sol";
import { StorageDeployment } from "../deployment/StorageDeployment.s.sol";

// Mocks
import { MockErc20 } from "../mocks/MockErc20.sol";
import { MockWNative } from "../mocks/MockWNative.sol";
import { MockPyth } from "pyth-sdk-solidity/MockPyth.sol";
import { MockCalculator } from "../mocks/MockCalculator.sol";
import { MockPerpStorage } from "../mocks/MockPerpStorage.sol";
import { MockVaultStorage } from "../mocks/MockVaultStorage.sol";
import { MockOracleMiddleware } from "../mocks/MockOracleMiddleware.sol";
import { MockWNative } from "../mocks/MockWNative.sol";
import { MockLiquidityService } from "../mocks/MockLiquidityService.sol";
import { MockTradeService } from "../mocks/MockTradeService.sol";
import { MockGlpManager } from "../mocks/MockGlpManager.sol";

import { Deployment } from "../../script/Deployment.s.sol";
import { StorageDeployment } from "../deployment/StorageDeployment.s.sol";

// Calculator
import { Calculator } from "@hmx/contracts/Calculator.sol";

// Handlers
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";

// Services
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";

// Storages
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

// Oracles
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";

import { PLPv2 } from "@hmx/contracts/PLPv2.sol";

// Handlers
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";

abstract contract BaseTest is TestBase, Deployment, StorageDeployment, StdAssertions, StdCheatsSafe {
  address internal ALICE;
  address internal BOB;
  address internal CAROL;
  address internal DAVE;

  // storages
  ConfigStorage internal configStorage;
  PerpStorage internal perpStorage;
  VaultStorage internal vaultStorage;

  // other contracts
  PLPv2 internal plp;
  Calculator internal calculator;

  // mock
  MockPyth internal mockPyth;
  MockCalculator internal mockCalculator;
  MockPerpStorage internal mockPerpStorage;
  MockVaultStorage internal mockVaultStorage;
  MockOracleMiddleware internal mockOracle;
  MockLiquidityService internal mockLiquidityService;
  MockTradeService internal mockTradeService;
  MockGlpManager internal mockGlpManager;

  MockWNative internal weth;
  MockErc20 internal wbtc;
  MockErc20 internal dai;
  MockErc20 internal usdc;
  MockErc20 internal usdt;

  MockErc20 internal bad;

  MockErc20 internal stkGlp;

  // market indexes
  uint256 ethMarketIndex;
  uint256 btcMarketIndex;

  bytes32 internal constant wethPriceId = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 internal constant wbtcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 internal constant daiPriceId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 internal constant usdcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000004;
  bytes32 internal constant usdtPriceId = 0x0000000000000000000000000000000000000000000000000000000000000005;

  constructor() {
    // Creating a mock Pyth instance with 60 seconds valid time period
    // and 1 wei for updating price.
    mockPyth = new MockPyth(60, 1);

    ALICE = makeAddr("Alice");
    BOB = makeAddr("BOB");
    CAROL = makeAddr("CAROL");
    DAVE = makeAddr("DAVE");

    weth = deployMockWNative();
    wbtc = deployMockErc20("Wrapped Bitcoin", "WBTC", 8);
    dai = deployMockErc20("DAI Stablecoin", "DAI", 18);
    usdc = deployMockErc20("USD Coin", "USDC", 6);
    usdt = deployMockErc20("USD Tether", "USDT", 6);
    bad = deployMockErc20("Bad Coin", "BAD", 2);
    stkGlp = deployMockErc20("Glp Coin", "GLP", 18);

    plp = new PLPv2();

    configStorage = deployConfigStorage();
    perpStorage = deployPerpStorage();
    vaultStorage = deployVaultStorage();

    mockOracle = new MockOracleMiddleware();
    mockCalculator = new MockCalculator(address(mockOracle));

    mockPerpStorage = new MockPerpStorage();
    mockVaultStorage = new MockVaultStorage();
    mockOracle = new MockOracleMiddleware();
    mockTradeService = new MockTradeService();

    mockGlpManager = new MockGlpManager();

    mockLiquidityService = new MockLiquidityService(
      address(configStorage),
      address(perpStorage),
      address(vaultStorage)
    );

    _setUpLiquidityConfig();
    _setUpSwapConfig();
    _setUpTradingConfig();
    _setUpAssetClassConfigs();
    _setUpMarketConfigs();
    _setUpPlpTokenConfigs();
    _setUpCollateralTokenConfigs();

    // set general config
    configStorage.setCalculator(address(mockCalculator));
    configStorage.setOracle(address(mockOracle));
    configStorage.setWeth(address(weth));
  }

  // --------- Deploy Helpers ---------
  function deployMockWNative() internal returns (MockWNative) {
    return new MockWNative();
  }

  function deployMockErc20(string memory name, string memory symbol, uint8 decimals) internal returns (MockErc20) {
    return new MockErc20(name, symbol, decimals);
  }

  function deployPerp88v2() internal returns (Deployment.DeployCoreReturnVars memory) {
    DeployCoreLocalVars memory deployCoreLocalVars = DeployCoreLocalVars({
      pyth: address(mockPyth),
      defaultOracleStaleTime: 300,
      minExecutionFee: 0,
      stkGlp: address(stkGlp),
      glpManager: address(mockGlpManager),
      weth: address(weth)
    });
    return deployCore(deployCoreLocalVars);
  }

  /**
   * HANDLER
   */

  function deployCrossMarginHandler(address _crossMarginService, address _pyth) internal returns (CrossMarginHandler) {
    return new CrossMarginHandler(_crossMarginService, _pyth);
  }

  /**
   * SERVICE
   */

  function deployCrossMarginService(
    address _configStorage,
    address _vaultStorage,
    address _calculator
  ) internal returns (CrossMarginService) {
    return new CrossMarginService(_configStorage, _vaultStorage, _calculator);
  }

  /**
   * CALCULATOR
   */

  function deployCalculator(
    address _oracle,
    address _vaultStorage,
    address _perpStorage,
    address _configStorage
  ) internal returns (Calculator) {
    return new Calculator(_oracle, _vaultStorage, _perpStorage, _configStorage);
  }

  /**
   * TEST HELPERS
   */

  /// @notice Helper function to create a price feed update data.
  /// @dev The price data is in the format of [wethPrice, wbtcPrice, daiPrice, usdcPrice] and in 8 decimals.
  /// @param priceData The price data to create the update data.
  function buildPythUpdateData(int64[] memory priceData) internal view returns (bytes[] memory) {
    require(priceData.length == 4, "invalid price data length");
    bytes[] memory priceDataBytes = new bytes[](4);
    for (uint256 i = 1; i <= priceData.length; ) {
      priceDataBytes[i - 1] = mockPyth.createPriceFeedUpdateData(
        bytes32(uint256(i)),
        priceData[i - 1] * 1e8,
        0,
        -8,
        priceData[i - 1] * 1e8,
        0,
        uint64(block.timestamp)
      );
      unchecked {
        ++i;
      }
    }
    return priceDataBytes;
  }

  /// --------- Setup helper ------------

  /// @notice set up liquidity config
  function _setUpLiquidityConfig() private {
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRate: 0,
        withdrawFeeRate: 0,
        maxPLPUtilization: (80 * 1e18) / 100,
        plpTotalTokenWeight: 0,
        plpSafetyBufferThreshold: 0,
        taxFeeRate: 5e15, // 0.5%
        flashLoanFeeRate: 0,
        dynamicFeeEnabled: false,
        enabled: true
      })
    );
  }

  /// @notice set up swap config
  function _setUpSwapConfig() private {
    configStorage.setSwapConfig(IConfigStorage.SwapConfig({ stablecoinSwapFeeRate: 0, swapFeeRate: 0 }));
  }

  /// @notice set up trading config
  function _setUpTradingConfig() private {
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({
        fundingInterval: 1,
        devFeeRate: 0.15 * 1e18,
        minProfitDuration: 0,
        maxPosition: 5
      })
    );
  }

  /// @notice set up all asset class configs in Perp
  function _setUpAssetClassConfigs() private {
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.0001 * 1e18
    });
    IConfigStorage.AssetClassConfig memory _forexConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.0002 * 1e18
    });
    configStorage.addAssetClassConfig(_cryptoConfig);
    configStorage.addAssetClassConfig(_forexConfig);
  }

  /// @notice set up all market configs in Perp
  function _setUpMarketConfigs() private {
    // add market config
    IConfigStorage.MarketConfig memory _ethConfig = IConfigStorage.MarketConfig({
      assetId: "ETH",
      assetClass: 0,
      exponent: 18,
      maxProfitRate: 9e18,
      minLeverage: 1 * 1e18,
      initialMarginFraction: 0.01 * 1e18,
      maintenanceMarginFraction: 0.005 * 1e18,
      increasePositionFeeRate: 0,
      decreasePositionFeeRate: 0,
      priceConfidentThreshold: 0.01 * 1e18,
      allowIncreasePosition: true,
      active: true,
      openInterest: IConfigStorage.OpenInterest({
        longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
        shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
      }),
      fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 0 })
    });

    IConfigStorage.MarketConfig memory _btcConfig = IConfigStorage.MarketConfig({
      assetId: "BTC",
      assetClass: 0,
      exponent: 8,
      maxProfitRate: 9e18,
      minLeverage: 1 * 1e18,
      initialMarginFraction: 0.01 * 1e18,
      maintenanceMarginFraction: 0.005 * 1e18,
      increasePositionFeeRate: 0,
      decreasePositionFeeRate: 0,
      priceConfidentThreshold: 0.01 * 1e18,
      allowIncreasePosition: true,
      active: true,
      openInterest: IConfigStorage.OpenInterest({
        longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
        shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
      }),
      fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 0 })
    });

    ethMarketIndex = configStorage.addMarketConfig(_ethConfig);
    btcMarketIndex = configStorage.addMarketConfig(_btcConfig);
  }

  /// @notice set up all plp token configs in Perp
  function _setUpPlpTokenConfigs() private {
    // set PLP token
    configStorage.setPLP(address(plp));

    // add Accepted Token for LP config
    IConfigStorage.PLPTokenConfig[] memory _plpTokenConfig = new IConfigStorage.PLPTokenConfig[](5);
    // WETH
    _plpTokenConfig[0] = IConfigStorage.PLPTokenConfig({
      decimals: 18,
      targetWeight: 2e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      isStableCoin: false,
      accepted: true
    });
    // WBTC
    _plpTokenConfig[1] = IConfigStorage.PLPTokenConfig({
      decimals: 8,
      targetWeight: 2e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      isStableCoin: false,
      accepted: true
    });
    // DAI
    _plpTokenConfig[2] = IConfigStorage.PLPTokenConfig({
      decimals: 18,
      targetWeight: 1e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      isStableCoin: true,
      accepted: true
    });
    // USDC
    _plpTokenConfig[3] = IConfigStorage.PLPTokenConfig({
      decimals: 6,
      targetWeight: 3e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      isStableCoin: true,
      accepted: true
    });
    // USDT
    _plpTokenConfig[4] = IConfigStorage.PLPTokenConfig({
      decimals: 6,
      targetWeight: 2e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      isStableCoin: true,
      accepted: true
    });

    address[] memory _tokens = new address[](5);
    _tokens[0] = address(weth);
    _tokens[1] = address(wbtc);
    _tokens[2] = address(dai);
    _tokens[3] = address(usdc);
    _tokens[4] = address(usdt);

    configStorage.addOrUpdateAcceptedToken(_tokens, _plpTokenConfig);
  }

  /// @notice set up all collateral token configs in Perp
  function _setUpCollateralTokenConfigs() private {
    IConfigStorage.CollateralTokenConfig memory _collatTokenConfigWeth = IConfigStorage.CollateralTokenConfig({
      decimals: weth.decimals(),
      collateralFactor: 0.8 * 1e18,
      isStableCoin: false,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(address(weth), _collatTokenConfigWeth);

    IConfigStorage.CollateralTokenConfig memory _collatTokenConfigWbtc = IConfigStorage.CollateralTokenConfig({
      decimals: wbtc.decimals(),
      collateralFactor: 0.9 * 1e18,
      isStableCoin: false,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(address(wbtc), _collatTokenConfigWbtc);
  }

  function abs(int256 x) external pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function deployLiquidityHandler(
    ILiquidityService _liquidityService,
    address _pyth,
    uint256 _minExecutionFee
  ) internal returns (LiquidityHandler) {
    return new LiquidityHandler(_liquidityService, _pyth, _minExecutionFee);
  }

  function deployLimitTradeHandler(
    address _weth,
    address _tradeService,
    address _pyth,
    uint256 _minExecutionFee
  ) internal returns (LimitTradeHandler) {
    return new LimitTradeHandler(_weth, _tradeService, _pyth, _minExecutionFee);
  }

  function deployMarketTradeHandler(address _tradeService, address _pyth) internal returns (MarketTradeHandler) {
    return new MarketTradeHandler(_tradeService, _pyth);
  }
}
