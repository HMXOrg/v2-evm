// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { TestBase } from "forge-std/Base.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { PythStructs } from "pyth-sdk-solidity/MockPyth.sol";

/**
 * Libraries
 */
import { Deployer } from "@hmx-test/libs/Deployer.sol";

// Mocks
import { MockErc20 } from "../mocks/MockErc20.sol";
import { MockWNative } from "../mocks/MockWNative.sol";
import { MockCalculator } from "../mocks/MockCalculator.sol";
import { MockPerpStorage } from "../mocks/MockPerpStorage.sol";
import { MockVaultStorage } from "../mocks/MockVaultStorage.sol";
import { MockOracleMiddleware } from "../mocks/MockOracleMiddleware.sol";
import { MockLiquidityService } from "../mocks/MockLiquidityService.sol";
import { MockTradeService } from "../mocks/MockTradeService.sol";
import { MockLiquidationService } from "../mocks/MockLiquidationService.sol";

// Contract
import { LeanPyth } from "@hmx/oracle/LeanPyth.sol";

// Interfaces
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

import { IPythAdapter } from "@hmx/oracle/interfaces/IPythAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracle/interfaces/IOracleMiddleware.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

abstract contract BaseTest is TestBase, StdAssertions, StdCheatsSafe {
  address internal ALICE;
  address internal BOB;
  address internal CAROL;
  address internal DAVE;
  address internal FEEVER;
  address internal BOT;

  // storages
  IConfigStorage internal configStorage;
  IPerpStorage internal perpStorage;
  IVaultStorage internal vaultStorage;

  // other contracts
  IPLPv2 internal plp;
  ICalculator internal calculator;

  // oracle
  IPythAdapter pythAdapter;
  IOracleMiddleware oracleMiddleware;
  LeanPyth leanPyth;

  // mock
  MockCalculator internal mockCalculator;
  MockPerpStorage internal mockPerpStorage;
  MockVaultStorage internal mockVaultStorage;
  MockOracleMiddleware internal mockOracle;
  MockLiquidityService internal mockLiquidityService;
  MockTradeService internal mockTradeService;
  MockLiquidationService internal mockLiquidationService;

  MockWNative internal weth;
  MockErc20 internal wbtc;
  MockErc20 internal dai;
  MockErc20 internal usdc;
  MockErc20 internal usdt;

  MockErc20 internal bad;

  // market indexes
  uint256 ethMarketIndex;
  uint256 btcMarketIndex;

  // Crypto
  bytes32 internal constant wethPriceId = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 internal constant wbtcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 internal constant daiPriceId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 internal constant usdcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000004;
  bytes32 internal constant usdtPriceId = 0x0000000000000000000000000000000000000000000000000000000000000005;

  bytes32 internal constant wethAssetId = "WETH";
  bytes32 internal constant wbtcAssetId = "WBTC";
  bytes32 internal constant daiAssetId = "DAI";
  bytes32 internal constant usdcAssetId = "USDC";
  bytes32 internal constant usdtAssetId = "USDT";

  // Fx
  bytes32 internal constant jpyPriceId = 0x0000000000000000000000000000000000000000000000000000000000000101;

  bytes32 internal constant jpyAssetId = "JPY";

  constructor() {
    ALICE = makeAddr("Alice");
    BOB = makeAddr("BOB");
    CAROL = makeAddr("CAROL");
    DAVE = makeAddr("DAVE");
    FEEVER = makeAddr("FEEVER");

    weth = new MockWNative();
    wbtc = new MockErc20("Wrapped Bitcoin", "WBTC", 8);
    dai = new MockErc20("DAI Stablecoin", "DAI", 18);
    usdc = new MockErc20("USD Coin", "USDC", 6);
    usdt = new MockErc20("USD Tether", "USDT", 6);
    bad = new MockErc20("Bad Coin", "BAD", 2);

    plp = Deployer.deployPLPv2();

    configStorage = Deployer.deployConfigStorage();
    perpStorage = Deployer.deployPerpStorage();
    vaultStorage = Deployer.deployVaultStorage();

    mockOracle = new MockOracleMiddleware();
    mockCalculator = new MockCalculator(address(mockOracle));

    mockPerpStorage = new MockPerpStorage();
    mockVaultStorage = new MockVaultStorage();
    mockOracle = new MockOracleMiddleware();
    mockTradeService = new MockTradeService();
    mockLiquidationService = new MockLiquidationService();

    leanPyth = new LeanPyth();
    pythAdapter = Deployer.deployPythAdapter(address(leanPyth));
    oracleMiddleware = Deployer.deployOracleMiddleware(address(pythAdapter));

    mockLiquidityService = new MockLiquidityService(
      address(configStorage),
      address(perpStorage),
      address(vaultStorage)
    );

    // configStorage setup
    _setUpAssetConfigs();
    _setUpLiquidityConfig();
    _setUpSwapConfig();
    _setUpTradingConfig();
    _setUpAssetClassConfigs();
    _setUpMarketConfigs();
    _setUpPlpTokenConfigs();
    _setUpCollateralTokenConfigs();
    _setUpLiquidationConfig();

    // set general config
    configStorage.setCalculator(address(mockCalculator));
    configStorage.setOracle(address(mockOracle));
    configStorage.setWeth(address(weth));
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
      priceDataBytes[i - 1] = _createPriceFeedUpdateData(
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
        depositFeeRateBPS: 0,
        withdrawFeeRateBPS: 0,
        maxPLPUtilizationBPS: 0.8 * 1e4,
        plpTotalTokenWeight: 0,
        plpSafetyBufferBPS: 0.6 * 1e4,
        taxFeeRateBPS: 0.005 * 1e4, // 0.5%
        flashLoanFeeRateBPS: 0,
        dynamicFeeEnabled: false,
        enabled: true
      })
    );
  }

  /// @notice set up swap config
  function _setUpSwapConfig() private {
    configStorage.setSwapConfig(IConfigStorage.SwapConfig({ stablecoinSwapFeeRateBPS: 0, swapFeeRateBPS: 0 }));
  }

  /// @notice set up trading config
  function _setUpTradingConfig() private {
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({
        fundingInterval: 1,
        devFeeRateBPS: 0.15 * 1e4,
        minProfitDuration: 0,
        maxPosition: 5
      })
    );
  }

  /// @notice set up all asset class configs in Perp
  function _setUpAssetClassConfigs() private {
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.0001 * 1e18 // 0.01% per fundingInterval
    });
    IConfigStorage.AssetClassConfig memory _forexConfig = IConfigStorage.AssetClassConfig({
      baseBorrowingRate: 0.0002 * 1e18 // 0.02% per fundingInterval
    });
    configStorage.addAssetClassConfig(_cryptoConfig);
    configStorage.addAssetClassConfig(_forexConfig);
  }

  /// @notice set up all market configs in Perp
  function _setUpMarketConfigs() private {
    // add market config
    IConfigStorage.MarketConfig memory _ethConfig = IConfigStorage.MarketConfig({
      assetId: wethAssetId,
      assetClass: 0,
      maxProfitRateBPS: 9 * 1e4,
      minLeverageBPS: 1 * 1e4,
      initialMarginFractionBPS: 0.01 * 1e4,
      maintenanceMarginFractionBPS: 0.005 * 1e4,
      increasePositionFeeRateBPS: 0,
      decreasePositionFeeRateBPS: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 0 })
    });

    IConfigStorage.MarketConfig memory _btcConfig = IConfigStorage.MarketConfig({
      assetId: wbtcAssetId,
      assetClass: 0,
      maxProfitRateBPS: 9 * 1e4,
      minLeverageBPS: 1 * 1e4,
      initialMarginFractionBPS: 0.01 * 1e4,
      maintenanceMarginFractionBPS: 0.005 * 1e4,
      increasePositionFeeRateBPS: 0,
      decreasePositionFeeRateBPS: 0,
      allowIncreasePosition: true,
      active: true,
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
      targetWeight: 2e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // WBTC
    _plpTokenConfig[1] = IConfigStorage.PLPTokenConfig({
      targetWeight: 2e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // DAI
    _plpTokenConfig[2] = IConfigStorage.PLPTokenConfig({
      targetWeight: 1e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // USDC
    _plpTokenConfig[3] = IConfigStorage.PLPTokenConfig({
      targetWeight: 3e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    // USDT
    _plpTokenConfig[4] = IConfigStorage.PLPTokenConfig({
      targetWeight: 2e17,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
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
      collateralFactorBPS: 0.8 * 1e4,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(wethAssetId, _collatTokenConfigWeth);

    IConfigStorage.CollateralTokenConfig memory _collatTokenConfigWbtc = IConfigStorage.CollateralTokenConfig({
      collateralFactorBPS: 0.9 * 1e4,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(wbtcAssetId, _collatTokenConfigWbtc);

    IConfigStorage.CollateralTokenConfig memory _collatTokenConfigUsdt = IConfigStorage.CollateralTokenConfig({
      collateralFactorBPS: 1 * 1e4,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(usdtAssetId, _collatTokenConfigUsdt);

    IConfigStorage.CollateralTokenConfig memory _collatTokenConfigUsdc = IConfigStorage.CollateralTokenConfig({
      collateralFactorBPS: 1 * 1e4,
      accepted: true,
      settleStrategy: address(0)
    });

    configStorage.setCollateralTokenConfig(usdcAssetId, _collatTokenConfigUsdc);
  }

  function _setUpLiquidationConfig() private {
    IConfigStorage.LiquidationConfig memory _liquidationConfig = IConfigStorage.LiquidationConfig({
      liquidationFeeUSDE30: 5 * 1e30
    });

    configStorage.setLiquidationConfig(_liquidationConfig);
  }

  function _setUpAssetConfigs() private {
    IConfigStorage.AssetConfig memory _assetConfigWeth = IConfigStorage.AssetConfig({
      tokenAddress: address(weth),
      assetId: wethAssetId,
      decimals: 18,
      isStableCoin: false
    });
    configStorage.setAssetConfig(wethAssetId, _assetConfigWeth);

    IConfigStorage.AssetConfig memory _assetConfigWbtc = IConfigStorage.AssetConfig({
      tokenAddress: address(wbtc),
      assetId: wbtcAssetId,
      decimals: 8,
      isStableCoin: false
    });
    configStorage.setAssetConfig(wbtcAssetId, _assetConfigWbtc);

    IConfigStorage.AssetConfig memory _assetConfigUsdt = IConfigStorage.AssetConfig({
      tokenAddress: address(usdt),
      assetId: usdtAssetId,
      decimals: 6,
      isStableCoin: true
    });
    configStorage.setAssetConfig(usdtAssetId, _assetConfigUsdt);

    IConfigStorage.AssetConfig memory _assetConfigUsdc = IConfigStorage.AssetConfig({
      tokenAddress: address(usdc),
      assetId: usdcAssetId,
      decimals: 6,
      isStableCoin: true
    });
    configStorage.setAssetConfig(usdcAssetId, _assetConfigUsdc);

    IConfigStorage.AssetConfig memory _assetConfigDai = IConfigStorage.AssetConfig({
      tokenAddress: address(dai),
      assetId: daiAssetId,
      decimals: 18,
      isStableCoin: true
    });
    configStorage.setAssetConfig(daiAssetId, _assetConfigDai);
  }

  // function _setPythUpdater() {
  //   pyth.setUpdater(configStorage, true);
  // }

  function _createPriceFeedUpdateData(
    bytes32 id,
    int64 price,
    uint64 conf,
    int32 expo,
    int64 emaPrice,
    uint64 emaConf,
    uint64 publishTime
  ) public pure returns (bytes memory priceFeedData) {
    PythStructs.PriceFeed memory priceFeed;

    priceFeed.id = id;

    priceFeed.price.price = price;
    priceFeed.price.conf = conf;
    priceFeed.price.expo = expo;
    priceFeed.price.publishTime = publishTime;

    priceFeed.emaPrice.price = emaPrice;
    priceFeed.emaPrice.conf = emaConf;
    priceFeed.emaPrice.expo = expo;
    priceFeed.emaPrice.publishTime = publishTime;

    priceFeedData = abi.encode(priceFeed);
  }

  function abs(int256 x) external pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
