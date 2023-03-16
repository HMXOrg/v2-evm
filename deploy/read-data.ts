import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, network } from "hardhat";
import {
  Calculator__factory,
  OracleMiddleware__factory,
  VaultStorage__factory,
  ERC20__factory,
  PLPv2__factory,
  PerpStorage__factory,
} from "../typechain";
import { getConfig } from "./utils/config";
import { MultiCall, JsonFragment } from "@indexed-finance/multicall";

const BigNumber = ethers.BigNumber;
const config = getConfig();
const subAccountId = 0;

const ethAssetId = "0x0000000000000000000000000000000000000000000000000000000000000001";
const wbtcAssetId = "0x0000000000000000000000000000000000000000000000000000000000000002";
const usdcAssetId = "0x0000000000000000000000000000000000000000000000000000000000000003";
const usdtAssetId = "0x0000000000000000000000000000000000000000000000000000000000000004";
const daiAssetId = "0x0000000000000000000000000000000000000000000000000000000000000005";
const appleAssetId = "0x0000000000000000000000000000000000000000000000000000000000000006";
const jpyAssetId = "0x0000000000000000000000000000000000000000000000000000000000000007";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const address = BigNumber.from(deployer.address).xor(subAccountId).toHexString();
  const provider = ethers.provider;
  const multi = new MultiCall(provider);

  const balances = await multi.getBalances(
    [config.tokens.usdc, config.tokens.usdt, config.tokens.dai, config.tokens.wbtc, config.tokens.plp],
    deployer.address
  );
  console.log("=== Wallet Balances ===");
  console.table([
    {
      token: "plp",
      balance: ethers.utils.formatUnits(balances[1][config.tokens.plp].toString(), 18),
    },
    {
      token: "usdc",
      balance: ethers.utils.formatUnits(balances[1][config.tokens.usdc].toString(), 6),
    },
    {
      token: "usdt",
      balance: ethers.utils.formatUnits(balances[1][config.tokens.usdt].toString(), 6),
    },
    {
      token: "dai",
      balance: ethers.utils.formatUnits(balances[1][config.tokens.dai].toString(), 18),
    },
    {
      token: "wbtc",
      balance: ethers.utils.formatUnits(balances[1][config.tokens.wbtc].toString(), 8),
    },
    {
      token: "eth",
      balance: ethers.utils.formatUnits(await provider.getBalance(deployer.address), 18),
    },
  ]);

  const inputs = [
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [deployer.address, config.tokens.usdc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [deployer.address, config.tokens.usdt],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [deployer.address, config.tokens.dai],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [deployer.address, config.tokens.weth],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [deployer.address, config.tokens.wbtc],
    },
    // Equity
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getEquity",
      args: [deployer.address, 0, ethAssetId],
    },
    // Free Collateral
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getFreeCollateral",
      args: [deployer.address, 0, ethAssetId],
    },
    // Prices
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestPrice",
      args: [usdcAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestPrice",
      args: [usdtAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestPrice",
      args: [daiAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestPrice",
      args: [ethAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestPrice",
      args: [wbtcAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestPrice",
      args: [appleAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestPrice",
      args: [jpyAssetId, false],
    },
    // PLP
    {
      interface: PLPv2__factory.abi,
      target: config.tokens.plp,
      function: "totalSupply",
      args: [],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getAUME30",
      args: [true, 0, ethAssetId],
    },
    // PLP Liquidity
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "plpLiquidity",
      args: [config.tokens.usdc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "plpLiquidity",
      args: [config.tokens.usdt],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "plpLiquidity",
      args: [config.tokens.dai],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "plpLiquidity",
      args: [config.tokens.weth],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "plpLiquidity",
      args: [config.tokens.wbtc],
    },
    // Asset Class
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "globalAssetClass",
      args: [0],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "globalAssetClass",
      args: [1],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "globalAssetClass",
      args: [2],
    },
    // Fees
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fees",
      args: [config.tokens.usdc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fees",
      args: [config.tokens.usdt],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fees",
      args: [config.tokens.dai],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fees",
      args: [config.tokens.weth],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fees",
      args: [config.tokens.wbtc],
    },
    // Dev Fees
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "devFees",
      args: [config.tokens.usdc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "devFees",
      args: [config.tokens.usdt],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "devFees",
      args: [config.tokens.dai],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "devFees",
      args: [config.tokens.weth],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "devFees",
      args: [config.tokens.wbtc],
    },
    // Global Markets
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "globalMarkets",
      args: [0],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "globalMarkets",
      args: [1],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "globalMarkets",
      args: [2],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "globalMarkets",
      args: [3],
    },
  ];
  const [
    blockNumber,
    [
      traderBalancesUsdc,
      traderBalancesUsdt,
      traderBalancesDai,
      traderBalancesWeth,
      traderBalancesWbtc,
      equity,
      freeCollateral,
      usdcPrice,
      usdtPrice,
      daiPrice,
      wethPrice,
      wbtcPrice,
      applePrice,
      jpyPrice,
      plpTotalSupply,
      plpAum,
      plpLiquidityUsdc,
      plpLiquidityUsdt,
      plpLiquidityDai,
      plpLiquidityWeth,
      plpLiquidityWbtc,
      assetClassCrypto,
      assetClassEquity,
      assetClassForex,
      feeUsdc,
      feeUsdt,
      feeDai,
      feeWeth,
      feeWbtc,
      devFeeUsdc,
      devFeeUsdt,
      devFeeDai,
      devFeeWeth,
      devFeeWbtc,
      ethusdMarket,
      btcusdMarket,
      applusdMarket,
      jpyusdMarket,
    ],
  ] = await multi.multiCall(inputs);

  const adaptivePriceInputs = [
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestAdaptivePrice",
      args: [
        ethAssetId,
        true,
        ethusdMarket.longOpenInterest.sub(ethusdMarket.shortOpenInterest),
        0,
        ethers.utils.parseUnits("3000000", 30),
      ],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestAdaptivePrice",
      args: [
        wbtcAssetId,
        true,
        ethusdMarket.longOpenInterest.sub(btcusdMarket.shortOpenInterest),
        0,
        ethers.utils.parseUnits("3000000", 30),
      ],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestAdaptivePrice",
      args: [
        appleAssetId,
        true,
        ethusdMarket.longOpenInterest.sub(applusdMarket.shortOpenInterest),
        0,
        ethers.utils.parseUnits("3000000", 30),
      ],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestAdaptivePrice",
      args: [
        jpyAssetId,
        true,
        ethusdMarket.longOpenInterest.sub(jpyusdMarket.shortOpenInterest),
        0,
        ethers.utils.parseUnits("3000000", 30),
      ],
    },
  ];
  const [blockNumber2, [ethusdAdaptivePrice, btcusdAdaptivePrice, applusdAdaptivePrice, jpyusdAdaptivePrice]] =
    await multi.multiCall(adaptivePriceInputs);

  console.log("=== Prices ===");
  console.log(ethers.utils.formatUnits(usdcPrice._price, 30));
  console.log(ethers.utils.formatUnits(usdtPrice._price, 30));
  console.log(ethers.utils.formatUnits(daiPrice._price, 30));
  console.log(ethers.utils.formatUnits(wethPrice._price, 30));
  console.log(ethers.utils.formatUnits(wbtcPrice._price, 30));
  console.log(ethers.utils.formatUnits(applePrice._price, 30));
  console.log(ethers.utils.formatUnits(jpyPrice._price, 30));
  console.log("=== Adaptive Prices ===");
  console.log(ethers.utils.formatUnits(ethusdAdaptivePrice._adaptivePrice, 30));
  console.log(ethers.utils.formatUnits(btcusdAdaptivePrice._adaptivePrice, 30));
  console.log(ethers.utils.formatUnits(applusdAdaptivePrice._adaptivePrice, 30));
  console.log(ethers.utils.formatUnits(jpyusdAdaptivePrice._adaptivePrice, 30));
  console.log("=== Cross Margin Account ===");
  console.table({
    equity: ethers.utils.formatUnits(equity, 30),
    freeCollateral: ethers.utils.formatUnits(freeCollateral, 30),
  });
  console.log("=== Trader Balances ===");
  console.table({
    usdc: ethers.utils.formatUnits(traderBalancesUsdc, 6),
    usdt: ethers.utils.formatUnits(traderBalancesUsdt, 6),
    dai: ethers.utils.formatUnits(traderBalancesDai, 18),
    weth: ethers.utils.formatUnits(traderBalancesWeth, 18),
    wbtc: ethers.utils.formatUnits(traderBalancesWbtc, 8),
  });
  console.log("=== PLP ===");
  console.table({
    plpTotalSupply: ethers.utils.formatUnits(plpTotalSupply, 18),
    plpAum: ethers.utils.formatUnits(plpAum, 30),
    plpPrice: plpAum.gt(0)
      ? ethers.utils.formatUnits(plpAum.mul(ethers.utils.parseEther("1")).div(plpTotalSupply), 30)
      : 0,
    usdc: ethers.utils.formatUnits(plpLiquidityUsdc, 6),
    usdt: ethers.utils.formatUnits(plpLiquidityUsdt, 6),
    dai: ethers.utils.formatUnits(plpLiquidityDai, 18),
    weth: ethers.utils.formatUnits(plpLiquidityWeth, 18),
    wbtc: ethers.utils.formatUnits(plpLiquidityWbtc, 8),
  });
  console.log("=== Asset Class ====");
  console.table({
    crypto: {
      reservedValue: ethers.utils.formatUnits(assetClassCrypto.reserveValueE30, 30),
      sumBorrowingRate: assetClassCrypto.sumBorrowingRate,
      lastBorrowingTime: assetClassCrypto.lastBorrowingTime,
    },
    equity: {
      reservedValue: ethers.utils.formatUnits(assetClassEquity.reserveValueE30, 30),
      sumBorrowingRate: assetClassEquity.sumBorrowingRate,
      lastBorrowingTime: assetClassEquity.lastBorrowingTime,
    },
    forex: {
      reservedValue: ethers.utils.formatUnits(assetClassForex.reserveValueE30, 30),
      sumBorrowingRate: assetClassForex.sumBorrowingRate,
      lastBorrowingTime: assetClassForex.lastBorrowingTime,
    },
  });
  console.log("=== Platform Fees ===");
  console.table({
    usdc: ethers.utils.formatUnits(feeUsdc, 6),
    usdt: ethers.utils.formatUnits(feeUsdt, 6),
    dai: ethers.utils.formatUnits(feeDai, 18),
    weth: ethers.utils.formatUnits(feeWeth, 18),
    wbtc: ethers.utils.formatUnits(feeWbtc, 8),
  });
  console.log("=== Dev Fees ===");
  console.table({
    usdc: ethers.utils.formatUnits(devFeeUsdc, 6),
    usdt: ethers.utils.formatUnits(devFeeUsdt, 6),
    dai: ethers.utils.formatUnits(devFeeDai, 18),
    weth: ethers.utils.formatUnits(devFeeWeth, 18),
    wbtc: ethers.utils.formatUnits(devFeeWbtc, 8),
  });
  console.log("=== Markets ===");
  console.table({
    ETHUSD: {
      longPositionSize: ethers.utils.formatUnits(ethusdMarket.longPositionSize, 30),
      longAvgPrice: ethers.utils.formatUnits(ethusdMarket.longAvgPrice, 30),
      longOpenInterest: ethusdMarket.longOpenInterest,
      shortPositionSize: ethers.utils.formatUnits(ethusdMarket.shortPositionSize, 30),
      shortAvgPrice: ethers.utils.formatUnits(ethusdMarket.shortAvgPrice, 30),
      shortOpenInterest: ethusdMarket.shortOpenInterest,
    },
    BTCUSD: {
      longPositionSize: ethers.utils.formatUnits(btcusdMarket.longPositionSize, 30),
      longAvgPrice: ethers.utils.formatUnits(btcusdMarket.longAvgPrice, 30),
      longOpenInterest: btcusdMarket.longOpenInterest,
      shortPositionSize: ethers.utils.formatUnits(btcusdMarket.shortPositionSize, 30),
      shortAvgPrice: ethers.utils.formatUnits(btcusdMarket.shortAvgPrice, 30),
      shortOpenInterest: btcusdMarket.shortOpenInterest,
    },
    APPLUSD: {
      longPositionSize: ethers.utils.formatUnits(applusdMarket.longPositionSize, 30),
      longAvgPrice: ethers.utils.formatUnits(applusdMarket.longAvgPrice, 30),
      longOpenInterest: applusdMarket.longOpenInterest,
      shortPositionSize: ethers.utils.formatUnits(applusdMarket.shortPositionSize, 30),
      shortAvgPrice: ethers.utils.formatUnits(applusdMarket.shortAvgPrice, 30),
      shortOpenInterest: applusdMarket.shortOpenInterest,
    },
    JPYUSD: {
      longPositionSize: ethers.utils.formatUnits(jpyusdMarket.longPositionSize, 30),
      longAvgPrice: ethers.utils.formatUnits(jpyusdMarket.longAvgPrice, 30),
      longOpenInterest: jpyusdMarket.longOpenInterest,
      shortPositionSize: ethers.utils.formatUnits(jpyusdMarket.shortPositionSize, 30),
      shortAvgPrice: ethers.utils.formatUnits(jpyusdMarket.shortAvgPrice, 30),
      shortOpenInterest: jpyusdMarket.shortOpenInterest,
    },
  });
};

export default func;
func.tags = ["ReadData"];
