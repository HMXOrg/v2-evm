// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// OZ
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Oracles
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

/// Handlers
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";

/// Services
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";

/// Storages
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

/// Vendors
import { IPermit2 } from "@hmx/interfaces/uniswap/IPermit2.sol";
import { IUniversalRouter } from "@hmx/interfaces/uniswap/IUniversalRouter.sol";

library ForkEnv {
  /// Account
  address internal constant deployer = 0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872;
  address internal constant multiSig = 0x6409ba830719cd0fE27ccB3051DF1b399C90df4a;

  /// Proxy
  ProxyAdmin internal constant proxyAdmin = ProxyAdmin(0x2E7983f9A1D08c57989eEA20adC9242321dA6589);

  /// Protocol
  /// Oracles
  IEcoPyth internal constant ecoPyth2 = IEcoPyth(0x8dc6A40465128B20DC712C6B765a5171EF30bB7B);
  /// Handlers
  CrossMarginHandler internal constant crossMarginHandler =
    CrossMarginHandler(payable(0xB189532c581afB4Fbe69aF6dC3CD36769525d446));
  LimitTradeHandler internal constant limitTradeHandler =
    LimitTradeHandler(payable(0xeE116128b9AAAdBcd1f7C18608C5114f594cf5D6));
  LiquidityHandler internal constant liquidityHandler =
    LiquidityHandler(payable(0x1c6b1264B022dE3c6f2AddE01D11fFC654297ba6));
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

  /// Vendors
  IUniversalRouter internal constant uniswapUniversalRouter =
    IUniversalRouter(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);
  IPermit2 internal constant uniswapPermit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

  /// Tokens
  IERC20 internal constant usdc_e = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
  IERC20 internal constant weth = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
  IERC20 internal constant wbtc = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
  IERC20 internal constant usdt = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
  IERC20 internal constant dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
  IERC20 internal constant pendle = IERC20(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8);
}
