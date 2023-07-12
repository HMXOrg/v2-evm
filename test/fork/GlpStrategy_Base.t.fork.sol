// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

// interfaces
import { IWNative } from "@hmx/interfaces/IWNative.sol";

import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";

import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";
import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";
import { IHLP } from "@hmx/contracts/interfaces/IHLP.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";

import { IStakedGlpStrategy } from "@hmx/strategies/interfaces/IStakedGlpStrategy.sol";
import { IConvertedGlpStrategy } from "@hmx/strategies/interfaces/IConvertedGlpStrategy.sol";
import { IReinvestNonHlpTokenStrategy } from "@hmx/strategies/interfaces/IReinvestNonHlpTokenStrategy.sol";
import { IWithdrawGlpStrategy } from "@hmx/strategies/interfaces/IWithdrawGlpStrategy.sol";

// GMX
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

// Pyth
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { EcoPyth } from "@hmx/oracles/EcoPyth.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

// HMX
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

// OZ
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

//tester
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
//deployment
import { Deployment } from "@hmx-script/foundry/Deployment.s.sol";

// Mock
import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

//Deployer
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { console } from "forge-std/console.sol";

// Openzeppelin
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

abstract contract GlpStrategy_Base is TestBase, StdAssertions, StdCheats {
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
  IEcoPyth internal pyth;
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
  uint256 internal constant maxExecutionChuck = 10; // 10 orders per time
  uint256 internal constant maxTrustPriceAge = type(uint32).max;

  bytes32 constant sGlpAssetId = "SGLP";

  bytes32 constant usdcAssetId = "USDC";
  bytes32 constant usdtAssetId = "USDT";
  bytes32 constant daiAssetId = "DAI";

  bytes32 constant ethAssetId = "ETH";
  bytes32 constant btcAssetId = "BTC";

  // handlers
  ILiquidityHandler liquidityHandler;
  ICrossMarginHandler crossMarginHandler;

  // services
  ILiquidityService liquidityService;
  ICrossMarginService crossMarginService;

  // TOKENS
  IERC20Upgradeable sglp;
  IERC20Upgradeable glp;
  IHLP hlpV2;
  IERC20Upgradeable usdc;

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

  IStakedGlpStrategy stakedGlpStrategy;
  IConvertedGlpStrategy convertedGlpStrategy;
  IReinvestNonHlpTokenStrategy reinvestStrategy;
  IWithdrawGlpStrategy withdrawStrategy;

  /* Testers */
  LiquidityTester liquidityTester;

  ProxyAdmin proxyAdmin;

  address keeper;
  address treasury;
  address FEEVER;

  function setUp() public virtual {
    _deployContracts();
    //setup hlp
    {
      hlpV2.setMinter(address(liquidityService), true);
    }

    //setup Strategy
    {
      stakedGlpStrategy.setWhiteListExecutor(address(keeper), true);
      convertedGlpStrategy.setWhiteListExecutor(address(crossMarginService), true);
      reinvestStrategy.setWhiteListExecutor(address(this), true);
      withdrawStrategy.setWhiteListExecutor(address(this), true);
    }

    // Config
    {
      configStorage.setSGlp(address(sglp));
      configStorage.setOracle(address(oracleMiddleware));
      configStorage.setCalculator(address(calculator));
      configStorage.setWeth(address(weth));
      configStorage.setHLP(address(hlpV2));
      configStorage.setServiceExecutor(address(liquidityService), address(liquidityHandler), true);
      configStorage.setServiceExecutor(address(crossMarginService), address(crossMarginHandler), true);
    }

    // Setup Storages
    {
      vaultStorage.setServiceExecutors(address(liquidityService), true);
      vaultStorage.setServiceExecutors(address(crossMarginService), true);
      vaultStorage.setServiceExecutors(address(stakedGlpStrategy), true);
      vaultStorage.setServiceExecutors(address(convertedGlpStrategy), true);
      vaultStorage.setServiceExecutors(address(reinvestStrategy), true);
      vaultStorage.setServiceExecutors(address(withdrawStrategy), true);
      vaultStorage.setServiceExecutors(address(this), true);

      vaultStorage.setStrategyAllowance(address(sglp), address(stakedGlpStrategy), address(rewardTracker));
      vaultStorage.setStrategyAllowance(address(sglp), address(convertedGlpStrategy), address(rewardRouter));
      vaultStorage.setStrategyAllowance(address(sglp), address(reinvestStrategy), address(rewardRouter));
      vaultStorage.setStrategyAllowance(address(sglp), address(withdrawStrategy), address(rewardRouter));

      vaultStorage.setStrategyFunctionSigAllowance(
        address(sglp),
        address(stakedGlpStrategy),
        IGmxRewardTracker.claim.selector
      );

      vaultStorage.setStrategyFunctionSigAllowance(
        address(sglp),
        address(convertedGlpStrategy),
        IGmxRewardRouterV2.unstakeAndRedeemGlp.selector
      );

      vaultStorage.setStrategyFunctionSigAllowance(
        address(sglp),
        address(reinvestStrategy),
        IGmxRewardRouterV2.mintAndStakeGlp.selector
      );

      vaultStorage.setStrategyFunctionSigAllowance(
        address(sglp),
        address(withdrawStrategy),
        IGmxRewardRouterV2.mintAndStakeGlp.selector
      );

      vaultStorage.setStrategyFunctionAllowExecutes(usdcAddress, usdcAddress, IERC20Upgradeable.approve.selector, true);
      vaultStorage.setStrategyFunctionAllowExecutes(wethAddress, wethAddress, IERC20Upgradeable.approve.selector, true);
      vaultStorage.setStrategyFunctionAllowExecutes(
        address(sglp),
        address(sglp),
        IERC20Upgradeable.approve.selector,
        true
      );
      vaultStorage.setStrategyFunctionAllowExecutes(
        usdcAddress,
        address(rewardRouter),
        IGmxRewardRouterV2.mintAndStakeGlp.selector,
        true
      );
      vaultStorage.setStrategyFunctionAllowExecutes(
        wethAddress,
        address(rewardRouter),
        IGmxRewardRouterV2.mintAndStakeGlp.selector,
        true
      );
      vaultStorage.setStrategyFunctionAllowExecutes(
        usdcAddress,
        address(rewardRouter),
        IGmxRewardRouterV2.unstakeAndRedeemGlp.selector,
        true
      );
      vaultStorage.setStrategyFunctionAllowExecutes(
        wethAddress,
        address(rewardRouter),
        IGmxRewardRouterV2.unstakeAndRedeemGlp.selector,
        true
      );

      perpStorage.setServiceExecutors(address(liquidityService), true);
    }

    // Set OrderExecutors
    {
      liquidityHandler.setOrderExecutor(keeper, true);
    }

    _setupPythConfig();
    _setupAssetConfig();
    _setupCollateralTokenConfig();
    _setupAssetPriceConfig();
    _setupLiquidityWithConfig();

    // Deploy LiquidityTester
    liquidityTester = new LiquidityTester(hlpV2, vaultStorage, perpStorage, FEEVER);
  }

  function _deployContracts() private {
    proxyAdmin = new ProxyAdmin();

    keeper = makeAddr("GlpStrategyKeeper");
    treasury = makeAddr("GlpStrategyTreasury");
    FEEVER = makeAddr("FEEVER");

    glp = IERC20Upgradeable(glpAddress);
    rewardRouter = IGmxRewardRouterV2(gmxRewardRouterV2Address);
    glpManager = IGmxGlpManager(glpManagerAddress);
    rewardTracker = IGmxRewardTracker(fglpAddress);
    sglp = IERC20Upgradeable(sGlpAddress);

    pyth = Deployer.deployEcoPyth(address(proxyAdmin));

    // Tokens
    hlpV2 = Deployer.deployHLP(address(proxyAdmin));

    weth = IWNative(wethAddress);
    usdc = IERC20Upgradeable(usdcAddress);

    vm.label(address(usdc), "USDC");
    vm.label(address(weth), "WETH");

    //deploy pythAdapter
    pythAdapter = Deployer.deployPythAdapter(address(proxyAdmin), address(pyth));

    //deploy stakedglpOracle
    stakedGlpOracleAdapter = Deployer.deployStakedGlpOracleAdapter(address(proxyAdmin), sglp, glpManager, sGlpAssetId);

    //deploy oracleMiddleWare
    oracleMiddleware = Deployer.deployOracleMiddleware(address(proxyAdmin), maxTrustPriceAge);

    // deploy configStorage
    configStorage = Deployer.deployConfigStorage(address(proxyAdmin));

    // deploy perpStorage
    perpStorage = Deployer.deployPerpStorage(address(proxyAdmin));

    // deploy vaultStorage
    vaultStorage = Deployer.deployVaultStorage(address(proxyAdmin));

    //deploy calculator
    calculator = Deployer.deployCalculator(
      address(proxyAdmin),
      address(oracleMiddleware),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );
    //deploy liquidityService
    liquidityService = Deployer.deployLiquidityService(
      address(proxyAdmin),
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );
    //deploy liquidityHandler
    liquidityHandler = Deployer.deployLiquidityHandler(
      address(proxyAdmin),
      address(liquidityService),
      address(pyth),
      executionOrderFee,
      maxExecutionChuck
    );

    // Deploy GlpStrategy
    IStakedGlpStrategy.StakedGlpStrategyConfig memory stakedGlpStrategyConfig = IStakedGlpStrategy
      .StakedGlpStrategyConfig(rewardRouter, rewardTracker, glpManager, oracleMiddleware, vaultStorage);

    stakedGlpStrategy = Deployer.deployStakedGlpStrategy(
      address(proxyAdmin),
      sglp,
      stakedGlpStrategyConfig,
      treasury,
      1000 // 10% of reinvest
    );

    // convertedGlp strategy
    convertedGlpStrategy = Deployer.deployConvertedGlpStrategy(address(proxyAdmin), sglp, rewardRouter, vaultStorage);

    // reinvest non-hlp token strategy
    reinvestStrategy = Deployer.deployReinvestNonHlpTokenStrategy(
      address(proxyAdmin),
      address(sglp),
      address(rewardRouter),
      address(vaultStorage),
      address(glpManager),
      address(calculator),
      1000
    );

    // withdraw GLP strategy
    withdrawStrategy = Deployer.deployWithdrawGlpStrategy(
      address(proxyAdmin),
      address(sglp),
      address(rewardRouter),
      address(vaultStorage),
      address(glpManager),
      address(calculator),
      1000
    );

    //deploy liquidityService
    liquidityService = Deployer.deployLiquidityService(
      address(proxyAdmin),
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );

    crossMarginService = Deployer.deployCrossMarginService(
      address(proxyAdmin),
      address(configStorage),
      address(vaultStorage),
      address(perpStorage),
      address(calculator),
      address(convertedGlpStrategy)
    );

    //deploy liquidityHandler
    liquidityHandler = Deployer.deployLiquidityHandler(
      address(proxyAdmin),
      address(liquidityService),
      address(pyth),
      executionOrderFee,
      maxExecutionChuck
    );
    crossMarginHandler = Deployer.deployCrossMarginHandler(
      address(proxyAdmin),
      address(crossMarginService),
      address(pyth),
      executionOrderFee,
      maxExecutionChuck
    );
  }

  function _setupLiquidityWithConfig() private {
    // Setup Liquidity Config
    // Assuming no deposit and withdraw fee.
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 30, // 0.3%
        withdrawFeeRateBPS: 30, // 0.3%
        maxHLPUtilizationBPS: 8000, // 80%
        hlpTotalTokenWeight: 0,
        hlpSafetyBufferBPS: 2000, // 20%
        taxFeeRateBPS: 50, // 0.5%
        flashLoanFeeRateBPS: 0,
        dynamicFeeEnabled: true,
        enabled: true
      })
    );

    // Add glp as a liquidity token
    address[] memory _tokens = new address[](3);
    _tokens[0] = address(sGlpAddress);
    _tokens[1] = address(usdc);
    _tokens[2] = wethAddress;

    IConfigStorage.HLPTokenConfig[] memory _hlpTokenConfig = new IConfigStorage.HLPTokenConfig[](_tokens.length);

    _hlpTokenConfig[0] = _buildAcceptedHLPTokenConfig({
      _targetWeight: 0.95 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.05 * 1e18
    });
    _hlpTokenConfig[1] = _buildAcceptedHLPTokenConfig({
      _targetWeight: 0.05 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.95 * 1e18
    });
    _hlpTokenConfig[2] = _buildAcceptedHLPTokenConfig({
      _targetWeight: 0,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.95 * 1e18
    });

    configStorage.addOrUpdateAcceptedToken(_tokens, _hlpTokenConfig);
  }

  function _setupCollateralTokenConfig() private {
    _addCollateralConfig(sGlpAssetId, 8000, true, address(0));
    _addCollateralConfig(usdcAssetId, 10000, true, address(0));
    _addCollateralConfig(usdtAssetId, 10000, true, address(0));
    _addCollateralConfig(daiAssetId, 10000, true, address(0));
    _addCollateralConfig(ethAssetId, 8000, true, address(0));
    _addCollateralConfig(btcAssetId, 8000, true, address(0));
  }

  /// @notice to add collateral config with some default value
  /// @param _assetId Asset's ID
  /// @param _collateralFactorBPS token reliability factor to calculate buying power, 1e4 = 100%
  /// @param _isAccepted accepted to deposit as collateral
  /// @param _settleStrategy determine token will be settled for NON HLP collateral, e.g. aUSDC redeemed as USDC
  function _addCollateralConfig(
    bytes32 _assetId,
    uint32 _collateralFactorBPS,
    bool _isAccepted,
    address _settleStrategy
  ) private {
    IConfigStorage.CollateralTokenConfig memory _collatTokenConfig;

    _collatTokenConfig.collateralFactorBPS = _collateralFactorBPS;
    _collatTokenConfig.accepted = _isAccepted;
    _collatTokenConfig.settleStrategy = _settleStrategy;

    configStorage.setCollateralTokenConfig(_assetId, _collatTokenConfig);
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

    _assetConfig = IConfigStorage.AssetConfig({
      tokenAddress: wethAddress,
      assetId: ethAssetId,
      decimals: 18,
      isStableCoin: false
    });

    configStorage.setAssetConfig(ethAssetId, _assetConfig);
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
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: ethAssetId,
        priceId: ethAssetId,
        price: 1889.82 * 1e8,
        exponent: -8,
        inverse: false,
        conf: 0,
        tickPrice: 75446
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
    oracleMiddleware.setAssetPriceConfig(ethAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
  }

  function _buildAcceptedHLPTokenConfig(
    uint256 _targetWeight,
    uint256 _bufferLiquidity,
    uint256 _maxWeightDiff
  ) private pure returns (IConfigStorage.HLPTokenConfig memory _config) {
    _config.targetWeight = _targetWeight;
    _config.bufferLiquidity = _bufferLiquidity;
    _config.maxWeightDiff = _maxWeightDiff;
    _config.accepted = true;
    return _config;
  }

  function addLiquidity(
    address _liquidityProvider,
    IERC20Upgradeable _tokenIn,
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
      executeHLPOrder(_orderIndex, _tickPrices, _publishTimeDiffs, _minPublishTime);
    }
  }

  function executeHLPOrder(
    uint256 _endIndex,
    int24[] memory _tickPrices,
    uint24[] memory _publishTimeDiffs,
    uint256 /*_minPublishTime*/
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

  /**
   * Cross Margin
   */
  /// @notice Helper function to deposit collateral via handler
  /// @param _account Trader's address
  /// @param _subAccountId Trader's sub-account ID
  /// @param _collateralToken Collateral token to deposit
  /// @param _depositAmount amount to deposit
  function depositCollateral(
    address _account,
    uint8 _subAccountId,
    IERC20Upgradeable _collateralToken,
    uint256 _depositAmount
  ) internal {
    vm.startPrank(_account);
    _collateralToken.approve(address(crossMarginHandler), _depositAmount);
    crossMarginHandler.depositCollateral(_subAccountId, address(_collateralToken), _depositAmount, false);
    vm.stopPrank();
  }
}
