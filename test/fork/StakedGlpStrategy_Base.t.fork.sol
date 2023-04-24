// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

// interfaces
import { IWNative } from "@hmx/interfaces/IWNative.sol";

import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";

// GMX
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

// Pyth
import { IPyth } from "lib/pyth-sdk-solidity/IPyth.sol";
import { EcoPyth } from "@hmx/oracles/EcoPyth.sol";

// HMX
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { StakedGlpStrategy } from "@hmx/strategies/StakedGlpStrategy.sol";
// OZ
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

//tester
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
//deployment
import { Deployment } from "@hmx-script/Deployment.s.sol";

// Mock
import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

//Deployer
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { console } from "forge-std/console.sol";

abstract contract StakedGlpStrategy_Base is TestBase, StdAssertions, StdCheats {
  struct AssetPythPriceData {
    bytes32 assetId;
    bytes32 priceId;
    int64 price;
    int64 exponent;
    uint64 conf;
    bool inverse;
    int24 tickPrice;
  }

  // ACTOR
  address internal constant ALICE = 0xBB0Ba69f99B18E255912c197C8a2bD48293D5797;

  // GMX
  address internal constant glpManagerAddress = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;
  address internal constant glpAddress = 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258;
  address internal constant sGlpAddress = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;
  address internal constant gmxRewardRouterV2Address = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
  address internal constant fglpAddress = 0x4e971a87900b931fF39d1Aad67697F49835400b6;
  address internal constant fsGlpAddress = 0x1aDDD80E6039594eE970E5872D247bf0414C8903;

  // PYTH
  EcoPyth internal pyth;
  // address internal constant pythAddress = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;
  bytes32 internal constant usdcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  AssetPythPriceData[] assetPythPriceDatas;
  bytes[] initialPriceFeedDatas;
  int24[] tickPrices;
  uint24[] publishTimeDiff;

  // TOKENS
  address internal constant wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address internal constant usdcAddress = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

  // HLP
  uint256 internal constant executionOrderFee = 0.0001 ether;
  bytes32 constant sGlpAssetId = "SGLP";
  bytes32 constant usdcAssetId = "USDC";

  // handlers
  ILiquidityHandler liquidityHandler;

  // services
  ILiquidityService liquidityService;

  // TOKENS
  IERC20 sglp;
  IERC20 glp;
  IPLPv2 plpV2;
  IERC20 usdc;

  IWNative weth; //for native

  // ORACLES
  IGmxGlpManager internal glpManager;
  IPythAdapter internal pythAdapter;
  IOracleAdapter internal stakedGlpOracleAdapter;
  IOracleMiddleware internal oracleMiddleware;

  // storages
  IConfigStorage configStorage;
  IPerpStorage perpStorage;
  IVaultStorage vaultStorage;

  // calculator
  ICalculator calculator;

  IGmxRewardRouterV2 rewardRouter;
  IGmxRewardTracker rewardTracker; //fglp contract

  IStrategy stakedGlpStrategy;

  /* Testers */
  LiquidityTester liquidityTester;

  address keeper;
  address treasury;
  address FEEVER;

  function setUp() public virtual {
    _deployContracts();
    //setup plp
    {
      plpV2.setMinter(address(liquidityService), true);
    }

    // Config
    {
      configStorage.setOracle(address(oracleMiddleware));
      configStorage.setCalculator(address(calculator));
      configStorage.setWeth(address(weth));
      configStorage.setPLP(address(plpV2));
      configStorage.setServiceExecutor(address(liquidityService), address(liquidityHandler), true);
    }

    // Setup Storages
    {
      vaultStorage.setServiceExecutors(address(liquidityService), true);
      vaultStorage.setServiceExecutors(address(stakedGlpStrategy), true);

      vaultStorage.setStrategyAllowance(address(sglp), address(stakedGlpStrategy), address(rewardTracker));

      perpStorage.setServiceExecutors(address(liquidityService), true);
    }

    // Set OrderExecutors
    {
      liquidityHandler.setOrderExecutor(keeper, true);
    }
    _setupPythConfig();
    _setupAssetConfig();
    _setupAssetPriceConfig();
    _setupLiquidityWithConfig();

    // Deploy LiquidityTester
    liquidityTester = new LiquidityTester(plpV2, vaultStorage, perpStorage, FEEVER);
  }

  function _deployContracts() private {
    keeper = makeAddr("GlpStrategyKeeper");
    treasury = makeAddr("GlpStrategyTreasury");
    FEEVER = makeAddr("FEEVER");

    glp = IERC20(glpAddress);
    rewardRouter = IGmxRewardRouterV2(gmxRewardRouterV2Address);
    glpManager = IGmxGlpManager(glpManagerAddress);
    rewardTracker = IGmxRewardTracker(fglpAddress);
    sglp = IERC20(sGlpAddress);

    pyth = new EcoPyth();

    // Tokens
    plpV2 = Deployer.deployPLPv2();

    weth = IWNative(wethAddress);
    usdc = IERC20(usdcAddress);

    vm.label(address(usdc), "USDC");
    vm.label(address(weth), "WETH");

    //deploy pythAdapter
    pythAdapter = Deployer.deployPythAdapter(address(pyth));

    //deploy stakedglpOracle
    stakedGlpOracleAdapter = Deployer.deployStakedGlpOracleAdapter(sglp, glpManager, sGlpAssetId);

    //deploy oracleMiddleWare
    oracleMiddleware = Deployer.deployOracleMiddleware();

    // deploy configStorage
    configStorage = Deployer.deployConfigStorage();

    // deploy perpStorage
    perpStorage = Deployer.deployPerpStorage();

    // deploy vaultStorage
    vaultStorage = Deployer.deployVaultStorage();

    //deploy calculator
    calculator = Deployer.deployCalculator(
      address(oracleMiddleware),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );
    //deploy liquidityService
    liquidityService = Deployer.deployLiquidityService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );
    //deploy liquidityHandler
    liquidityHandler = Deployer.deployLiquidityHandler(address(liquidityService), address(pyth), executionOrderFee);

    // Deploy GlpStrategy

    stakedGlpStrategy = Deployer.deployStakedGlpStrategy(
      sglp,
      rewardRouter,
      rewardTracker,
      glpManager,
      oracleMiddleware,
      vaultStorage,
      keeper,
      treasury,
      1000 // 10% of reinvest
    );
  }

  function _setupLiquidityWithConfig() private {
    // Setup Liquidity Config
    // Assuming no deposit and withdraw fee.
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 30, // 0.3%
        withdrawFeeRateBPS: 30, // 0.3%
        maxPLPUtilizationBPS: 8000, // 80%
        plpTotalTokenWeight: 0,
        plpSafetyBufferBPS: 2000, // 20%
        taxFeeRateBPS: 50, // 0.5%
        flashLoanFeeRateBPS: 0, //
        dynamicFeeEnabled: true,
        enabled: true
      })
    );

    // Add glp as a liquidity token
    address[] memory _tokens = new address[](2);
    _tokens[0] = address(sGlpAddress);
    _tokens[1] = address(usdc);

    IConfigStorage.PLPTokenConfig[] memory _plpTokenConfig = new IConfigStorage.PLPTokenConfig[](_tokens.length);

    _plpTokenConfig[0] = _buildAcceptedPLPTokenConfig({
      _targetWeight: 0.95 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.05 * 1e18
    });
    _plpTokenConfig[1] = _buildAcceptedPLPTokenConfig({
      _targetWeight: 0.05 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.95 * 1e18
    });

    configStorage.addOrUpdateAcceptedToken(_tokens, _plpTokenConfig);
  }

  function _setupAssetConfig() private {
    // Set AssetConfig for glp
    IConfigStorage.AssetConfig memory _assetConfig = IConfigStorage.AssetConfig({
      tokenAddress: sGlpAddress,
      assetId: sGlpAssetId,
      decimals: 18,
      isStableCoin: false
    });
    configStorage.setAssetConfig(sGlpAssetId, _assetConfig);

    _assetConfig = IConfigStorage.AssetConfig({
      tokenAddress: usdcAddress,
      assetId: usdcAssetId,
      decimals: 6,
      isStableCoin: true
    });

    configStorage.setAssetConfig(usdcAssetId, _assetConfig);
  }

  function _setupPythConfig() private {
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: usdcAssetId,
        priceId: usdcPriceId,
        price: 1 * 1e8,
        exponent: -8,
        inverse: false,
        conf: 0,
        tickPrice: 0
      })
    );
    AssetPythPriceData memory _data;
    for (uint256 i = 0; i < assetPythPriceDatas.length; ) {
      _data = assetPythPriceDatas[i];

      // set PythId
      pythAdapter.setConfig(_data.assetId, _data.assetId, _data.inverse);
      pyth.insertAssetId(_data.assetId);

      tickPrices.push(_data.tickPrice);
      publishTimeDiff.push(0);
      unchecked {
        ++i;
      }
    }
    // set UpdatePriceFeed
    pyth.setUpdater(address(this), true);
    // pyth.setUpdater(address(keeper), true);
    pyth.setUpdater(address(liquidityHandler), true);
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiff);
    pyth.updatePriceFeeds(priceUpdateData, publishTimeUpdateData, block.timestamp, keccak256("someEncodedVaas"));
    skip(1);
  }

  function _setupAssetPriceConfig() private {
    uint32 _confidenceThresholdE6 = 2500; // 2.5% for test only
    uint32 _trustPriceAge = type(uint32).max; // set max for test only

    oracleMiddleware.setAssetPriceConfig(
      sGlpAssetId,
      _confidenceThresholdE6,
      _trustPriceAge,
      address(stakedGlpOracleAdapter)
    );

    oracleMiddleware.setAssetPriceConfig(usdcAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
  }

  function _buildAcceptedPLPTokenConfig(
    uint256 _targetWeight,
    uint256 _bufferLiquidity,
    uint256 _maxWeightDiff
  ) private pure returns (IConfigStorage.PLPTokenConfig memory _config) {
    _config.targetWeight = _targetWeight;
    _config.bufferLiquidity = _bufferLiquidity;
    _config.maxWeightDiff = _maxWeightDiff;
    _config.accepted = true;
    return _config;
  }

  function addLiquidity(
    address _liquidityProvider,
    ERC20 _tokenIn,
    uint256 _amountIn,
    uint256 _executionFee,
    int24[] memory _tickPrices,
    uint24[] memory _publishTimeDiffs,
    uint256 _minPublishTime,
    bool executeNow
  ) internal {
    vm.startPrank(_liquidityProvider);
    _tokenIn.approve(address(liquidityHandler), _amountIn);
    /// note: minOut always 0 to make test passed
    /// note: shouldWrap treat as false when only GLP could be liquidity
    uint256 _orderIndex = liquidityHandler.createAddLiquidityOrder{ value: _executionFee }(
      address(_tokenIn),
      _amountIn,
      0,
      _executionFee,
      false
    );
    vm.stopPrank();

    if (executeNow) {
      executePLPOrder(_orderIndex, _tickPrices, _publishTimeDiffs, _minPublishTime);
    }
  }

  function executePLPOrder(
    uint256 _endIndex,
    int24[] memory _tickPrices,
    uint24[] memory _publishTimeDiffs,
    uint256 _minPublishTime
  ) internal {
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(_tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(_publishTimeDiffs);

    vm.startPrank(keeper);
    liquidityHandler.executeOrder(
      _endIndex,
      payable(FEEVER),
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );
    vm.stopPrank();
  }
}
