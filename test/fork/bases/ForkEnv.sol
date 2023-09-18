// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// OZ
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Oracles
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";

/// Readers
import { IOrderReader } from "@hmx/readers/interfaces/IOrderReader.sol";
import { ILiquidationReader } from "@hmx/readers/interfaces/ILiquidationReader.sol";
import { IPositionReader } from "@hmx/readers/interfaces/IPositionReader.sol";

/// Handlers
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";

/// Services
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";

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

library ForkEnv {
  /// Account
  address internal constant deployer = 0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872;
  address internal constant multiSig = 0x6409ba830719cd0fE27ccB3051DF1b399C90df4a;
  address internal constant glpWhale = 0x97bb6679ae5a6c66fFb105bA427B07E2F7fB561e;
  address internal constant liquidityOrderExecutor = 0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E;
  address internal constant limitOrderExecutor = 0x7FDD623c90a0097465170EdD352Be27A9f3ad817;

  /// Proxy
  ProxyAdmin internal constant proxyAdmin = ProxyAdmin(0x2E7983f9A1D08c57989eEA20adC9242321dA6589);

  /// Protocol
  /// Oracles
  IEcoPyth internal constant ecoPyth2 = IEcoPyth(0x8dc6A40465128B20DC712C6B765a5171EF30bB7B);
  IEcoPythCalldataBuilder internal constant ecoPythBuilder =
    IEcoPythCalldataBuilder(0x4c3eC30d33c6CfC8B0806Bf049eA907FE4a0AB4F); // UnsafeEcoPythCalldataBuilder
  IPythAdapter internal constant pythAdapter = IPythAdapter(0x34338314236df25220b55F90F7E8Fc30B620D242);
  IOracleMiddleware internal constant oracleMiddleware = IOracleMiddleware(0x9c83e1046dA4727F05C6764c017C6E1757596592);
  /// Handlers
  CrossMarginHandler internal constant crossMarginHandler =
    CrossMarginHandler(payable(0xB189532c581afB4Fbe69aF6dC3CD36769525d446));
  LimitTradeHandler internal constant limitTradeHandler =
    LimitTradeHandler(payable(0xeE116128b9AAAdBcd1f7C18608C5114f594cf5D6));
  LiquidityHandler internal constant liquidityHandler =
    LiquidityHandler(payable(0x1c6b1264B022dE3c6f2AddE01D11fFC654297ba6));
  IBotHandler internal constant botHandler = IBotHandler(0xD4CcbDEbE59E84546fd3c4B91fEA86753Aa3B671);
  // readers
  ILiquidationReader internal constant liquidationReader =
    ILiquidationReader(0x9f13335e769208a2545047aCb0ea386Cce7F5f8F);
  IPositionReader internal constant positionReader = IPositionReader(0x64706D5f177B892b1cEebe49cd9F02B90BB6FF03);
  IOrderReader internal constant orderReader = IOrderReader(0x0E6be5E7891f0835bb9E2a4F5410698E2aa02614);
  /// Services
  CrossMarginService internal constant crossMarginService =
    CrossMarginService(0x0a8D9c0A4a039dDe3Cb825fF4c2f063f8B54313A);
  LiquidationService internal constant liquidationService =
    LiquidationService(0x34E89DEd96340A177856fD822366AfC584438750);
  LiquidityService internal constant liquidityService = LiquidityService(0xE7D96684A56e60ffBAAe0fC0683879da48daB383);
  TradeService internal constant tradeService = TradeService(0xcf533D0eEFB072D1BB68e201EAFc5368764daA0E);
  /// Storages
  ConfigStorage internal constant configStorage = ConfigStorage(0xF4F7123fFe42c4C90A4bCDD2317D397E0B7d7cc0);
  PerpStorage internal constant perpStorage = PerpStorage(0x97e94BdA44a2Df784Ab6535aaE2D62EFC6D2e303);
  VaultStorage internal constant vaultStorage = VaultStorage(0x56CC5A9c0788e674f17F7555dC8D3e2F1C0313C0);

  ITradingStaking internal constant hlpStaking = ITradingStaking(0xbE8f8AF5953869222eA8D39F1Be9d03766010B1C);

  /// Vendors
  /// Uniswap
  IUniversalRouter internal constant uniswapUniversalRouter =
    IUniversalRouter(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);
  IPermit2 internal constant uniswapPermit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
  /// GMX
  IERC20 internal constant sGlp = IERC20(0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf);
  IGmxGlpManager internal constant glpManager = IGmxGlpManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18);
  IGmxRewardRouterV2 internal constant gmxRewardRouterV2 =
    IGmxRewardRouterV2(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);
  IGmxVault internal constant gmxVault = IGmxVault(0x489ee077994B6658eAfA855C308275EAd8097C4A);
  /// Curve
  IStableSwap internal constant curveWstEthPool = IStableSwap(0x6eB2dc694eB516B16Dc9FBc678C60052BbdD7d80);

  ITradeHelper internal constant tradeHelper = ITradeHelper(0x963Cbe4cFcDC58795869be74b80A328b022DE00C);

  /// Tokens
  IERC20 internal constant usdc_e = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
  IERC20 internal constant weth = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
  IERC20 internal constant wbtc = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
  IERC20 internal constant usdt = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
  IERC20 internal constant dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
  IERC20 internal constant pendle = IERC20(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8);
  IERC20 internal constant arb = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
  IERC20 internal constant sglp = IERC20(0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf);
  IERC20 internal constant wstEth = IERC20(0x5979D7b546E38E414F7E9822514be443A4800529);


  IERC20 internal constant hlp = IERC20(0x4307fbDCD9Ec7AEA5a1c2958deCaa6f316952bAb);
}
