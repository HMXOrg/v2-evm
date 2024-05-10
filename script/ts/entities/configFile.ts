import { strategies } from "../../../typechain/src";

export interface BaseConfig {
  proxyAdmin: string;
  multicall: string;
  timelock: string;
  safe: string;
  storages: Storages;
  handlers: Handlers;
  helpers: Helpers;
  services: Services;
  oracles: Oracles;
  tokens: Tokens;
  vendors: Vendors;
  strategies: Strategies;
  hooks: Hooks;
  calculator: string;
  adaptiveFeeCalculator: string;
  staking: Staking;
  rewardDistributor: string;
  reader: Readers;
  extension: Extension;
}

export interface Storages {
  config: string;
  perp: string;
  vault: string;
}

export interface Handlers {
  bot: string;
  crossMargin: string;
  limitTrade: string;
  liquidity: string;
  rebalanceHLP?: string;
  ext01?: string;
  rebalanceHLPv2?: string;
  intent?: string;
}

export interface Helpers {
  trade: string;
  limitTrade?: string;
  tradeOrder?: string;
}

export interface Services {
  crossMargin: string;
  liquidity: string;
  liquidation: string;
  trade: string;
  rebalanceHLP?: string;
  rebalanceHLPv2?: string;
  gas?: string;
}

export interface Oracles {
  ecoPyth?: string;
  ecoPyth2?: string;
  pythAdapter: string;
  sglpStakedAdapter?: string;
  middleware: string;
  ecoPythCalldataBuilder?: string;
  unsafeEcoPythCalldataBuilder?: string;
  ecoPythCalldataBuilder2?: string;
  unsafeEcoPythCalldataBuilder2?: string;
  ecoPythCalldataBuilder3?: string;
  unsafeEcoPythCalldataBuilder3?: string;
  onChainPriceLens: string;
  calcPriceLens: string;
  priceAdapters: PriceAdapters;
  orderbook?: string;
}

export interface PriceAdapters {
  glp?: string;
  wstEth?: string;
  hlp: string;
  gmBTCUSD?: string;
  gmETHUSD?: string;
  dix: string;
  ybeth?: string;
  ybusdb?: string;
  ybeth2?: string;
  ybusdb2?: string;
}

export interface Staking {
  trading: string;
  tlc: string;
  hlp: string;
}

export interface Keeper {
  upKeepUniV3LM: string;
}

export interface Hlp {
  address: string;
  rewarders: Rewarder[];
}

export interface Rewarder {
  name: string;
  address: string;
}

export interface Hmx {
  address: string;
  rewarders: Rewarder2[];
}

export interface Rewarder2 {
  name: string;
  address: string;
}

export interface Trading {
  address: string;
  rewarders: Rewarder3[];
}

export interface Rewarder3 {
  name: string;
  marketIndex?: number;
  address: string;
}

export interface Tlc {
  address: string;
  rewarders: Rewarder4[];
}

export interface Rewarder4 {
  name: string;
  address: string;
}

export interface UniV3LiquidityMining {
  address: string;
}

export interface Tokens {
  hlp: string;
  weth: string;
  wbtc?: string;
  usdt?: string;
  usdc?: string;
  dai?: string;
  sglp?: string;
  traderLoyaltyCredit: string;
  arb?: string;
  wstEth?: string;
  gmBTCUSD?: string;
  gmETHUSD?: string;
  usdcNative?: string;
  usdb?: string;
  ybeth?: string;
  ybusdb?: string;
  ybeth2?: string;
  ybusdb2?: string;
}

export interface Readers {
  order: string;
  position: string;
  liquidation: string;
  collateral?: string;
}

export interface Vendors {
  gmx?: GmxVendor;
  gmxV2?: GmxV2Vendor;
  uniswap?: UniswapVendor;
  curve?: CurveVendor;
  chainlink?: ChainlinkVendor;
  oneInch?: OneInchVendor;
  thruster?: UniswapVendor;
}

export interface GmxVendor {
  glpManager: string;
  rewardRouterV2: string;
  rewardTracker: string;
  gmxVault: string;
}

export interface GmxV2Vendor {
  oracle: string;
  exchangeRouter: string;
  depositVault: string;
  depositUtils: string;
  depositStoreUtils: string;
  executeDepositUtils: string;
  depositHandler: string;
  withdrawalVault: string;
  withdrawalUtils: string;
  withdrawalStoreUtils: string;
  executeWithdrawalUtils: string;
  withdrawalHandler: string;
  marketUtils: string;
  marketStoreUtils: string;
  dataStore: string;
  roleStore: string;
  reader: string;
}
export interface UniswapVendor {
  permit2: string;
  universalRouter: string;
}
export interface CurveVendor {
  wstEthEthPool?: string;
  usdcUsdtPool?: string;
}
export interface ChainlinkVendor {
  wstEthEthPriceFeed: string;
  ethUsdPriceFeed: string;
}
export interface OneInchVendor {
  router: string;
}

export interface Strategies {
  stakedGlpStrategy?: string;
  convertedGlpStrategy?: string;
  erc20Approve?: string;
  distributeSTIPARB?: string;
}

export interface Hooks {
  tradingStaking: string;
  tlc: string;
}

export interface GmxV2 {
  oracle: string;
  exchangeRouter: string;
  depositVault: string;
  depositUtils: string;
  depositStoreUtils: string;
  executeDepositUtils: string;
  depositHandler: string;
  withdrawalVault: string;
  withdrawalUtils: string;
  withdrawalStoreUtils: string;
  executeWithdrawalUtils: string;
  withdrawalHandler: string;
  marketUtils: string;
  marketStoreUtils: string;
  dataStore: string;
  roleStore: string;
  reader: string;
}

export interface Uniswap {
  factory: string;
  nonfungiblePositionManager: string;
  swapRouter: string;
  hmxEthLpPool: string;
}

export interface Extension {
  switchCollateralRouter: string;
  dexter: Dexter;
}

export interface Dexter {
  uniswapV3?: string;
  curve?: string;
  glp?: string;
  erc4626?: string;
  thruster?: string;
}
