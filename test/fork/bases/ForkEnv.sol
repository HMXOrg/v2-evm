// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { stdJson } from "forge-std/StdJson.sol";
import { Test } from "forge-std/Test.sol";

/// OZ
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Oracles
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { OnChainPriceLens } from "@hmx/oracles/OnChainPriceLens.sol";

/// Readers
import { IOrderReader } from "@hmx/readers/interfaces/IOrderReader.sol";
import { ILiquidationReader } from "@hmx/readers/interfaces/ILiquidationReader.sol";
import { IPositionReader } from "@hmx/readers/interfaces/IPositionReader.sol";

/// Handlers
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";
import { RebalanceHLPHandler } from "@hmx/handlers/RebalanceHLPHandler.sol";

/// Services
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";
import { RebalanceHLPService } from "@hmx/services/RebalanceHLPService.sol";

/// Storages
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";

/// Vendors
/// Uniswap
import { IPermit2 } from "@hmx/interfaces/uniswap/IPermit2.sol";
import { IUniversalRouter } from "@hmx/interfaces/uniswap/IUniversalRouter.sol";
/// GMX
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IGmxVault } from "@hmx/interfaces/gmx/IGmxVault.sol";
/// Curve
import { IStableSwap } from "@hmx/interfaces/curve/IStableSwap.sol";

import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IGmxV2Reader } from "@hmx/interfaces/gmxV2/IGmxV2Reader.sol";

import { AdaptiveFeeCalculator } from "@hmx/contracts/AdaptiveFeeCalculator.sol";
import { OrderbookOracle } from "@hmx/oracles/OrderbookOracle.sol";

abstract contract ForkEnv is Test {
  using stdJson for string;

  string json = vm.readFile("configs/arbitrum.mainnet.json");

  function getAddress(string memory key) internal view returns (address _value) {
    return abi.decode(json.parseRaw(key), (address));
  }

  /// Account
  address internal constant deployer = 0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872;
  address internal constant multiSig = 0x6409ba830719cd0fE27ccB3051DF1b399C90df4a;
  address internal constant glpWhale = 0x97bb6679ae5a6c66fFb105bA427B07E2F7fB561e;
  address internal constant liquidityOrderExecutor = 0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E;
  address internal constant positionManager = 0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E;
  address internal constant limitOrderExecutor = 0x7FDD623c90a0097465170EdD352Be27A9f3ad817;

  address public ALICE = makeAddr("Alice");
  address public BOB = makeAddr("Bob");

  /// Proxy
  ProxyAdmin internal proxyAdmin = ProxyAdmin(getAddress(".proxyAdmin"));

  /// Protocol
  /// Oracles
  IEcoPyth internal ecoPyth2 = IEcoPyth(getAddress(".oracles.ecoPyth2"));
  IEcoPythCalldataBuilder internal ecoPythBuilder =
    IEcoPythCalldataBuilder(getAddress(".oracles.unsafeEcoPythCalldataBuilder")); // UnsafeEcoPythCalldataBuilder
  IPythAdapter internal pythAdapter = IPythAdapter(getAddress(".oracles.pythAdapter"));
  IOracleMiddleware internal oracleMiddleware = IOracleMiddleware(getAddress(".oracles.middleware"));
  OnChainPriceLens internal onChainPriceLens = OnChainPriceLens(getAddress(".oracles.onChainPriceLens"));
  /// Handlers
  CrossMarginHandler internal crossMarginHandler = CrossMarginHandler(payable(getAddress(".handlers.crossMargin")));
  LimitTradeHandler internal limitTradeHandler = LimitTradeHandler(payable(getAddress(".handlers.limitTrade")));
  LiquidityHandler internal liquidityHandler = LiquidityHandler(payable(getAddress(".handlers.liquidity")));
  IBotHandler internal botHandler = IBotHandler(getAddress(".handlers.bot"));
  RebalanceHLPHandler internal rebalanceHLPHandler = RebalanceHLPHandler(getAddress(".handlers.rebalanceHLP"));

  // readers
  ILiquidationReader internal liquidationReader = ILiquidationReader(getAddress(".reader.liquidation"));
  IPositionReader internal positionReader = IPositionReader(getAddress(".reader.position"));
  IOrderReader internal orderReader = IOrderReader(getAddress(".reader.order"));
  /// Services
  CrossMarginService internal crossMarginService = CrossMarginService(getAddress(".services.crossMargin"));
  LiquidationService internal liquidationService = LiquidationService(getAddress(".services.liquidation"));
  LiquidityService internal liquidityService = LiquidityService(getAddress(".services.liquidity"));
  TradeService internal tradeService = TradeService(getAddress(".services.trade"));
  RebalanceHLPService internal rebalanceHLPService = RebalanceHLPService(getAddress(".services.rebalanceHLP"));

  /// Storages
  ConfigStorage internal configStorage = ConfigStorage(getAddress(".storages.config"));
  PerpStorage internal perpStorage = PerpStorage(getAddress(".storages.perp"));
  VaultStorage internal vaultStorage = VaultStorage(getAddress(".storages.vault"));

  ICalculator internal calculator = ICalculator(getAddress(".calculator"));

  ITradingStaking internal hlpStaking = ITradingStaking(getAddress(".staking.hlp"));

  /// Vendors
  /// Uniswap
  IUniversalRouter internal uniswapUniversalRouter = IUniversalRouter(getAddress(".vendors.uniswap.universalRouter"));
  IPermit2 internal uniswapPermit2 = IPermit2(getAddress(".vendors.uniswap.permit2"));
  /// GMX
  IGmxGlpManager internal glpManager = IGmxGlpManager(getAddress(".vendors.gmx.glpManager"));
  IGmxRewardRouterV2 internal gmxRewardRouterV2 = IGmxRewardRouterV2(getAddress(".vendors.gmx.rewardRouterV2"));
  IGmxVault internal gmxVault = IGmxVault(getAddress(".vendors.gmx.gmxVault"));
  /// GMX V2
  IGmxV2Reader internal gmxV2Reader = IGmxV2Reader(getAddress(".vendors.gmxV2.reader"));
  address internal gmxV2DataStore = address(getAddress(".vendors.gmxV2.dataStore"));
  /// Curve
  IStableSwap internal curveWstEthPool = IStableSwap(getAddress(".vendors.curve.wstEthEthPool"));

  ITradeHelper internal tradeHelper = ITradeHelper(getAddress(".helpers.trade"));

  /// Tokens
  IERC20 internal usdc_e = IERC20(getAddress(".tokens.usdc"));
  IERC20 internal usdc = IERC20(getAddress(".tokens.usdcCircle"));
  IERC20 internal weth = IERC20(getAddress(".tokens.weth"));
  IERC20 internal wbtc = IERC20(getAddress(".tokens.wbtc"));
  IERC20 internal usdt = IERC20(getAddress(".tokens.usdt"));
  IERC20 internal dai = IERC20(getAddress(".tokens.dai"));
  IERC20 internal constant pendle = IERC20(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8);
  IERC20 internal arb = IERC20(getAddress(".tokens.arb"));
  IERC20 internal sglp = IERC20(getAddress(".tokens.sglp"));
  IERC20 internal wstEth = IERC20(getAddress(".tokens.wstEth"));
  IERC20 internal hlp = IERC20(getAddress(".tokens.hlp"));
  IERC20 internal gmBTCUSD = IERC20(getAddress(".tokens.gmBTCUSD"));
  IERC20 internal gmETHUSD = IERC20(getAddress(".tokens.gmETHUSD"));

  AdaptiveFeeCalculator adaptiveFeeCalculator;
  OrderbookOracle orderbookOracle;
}
