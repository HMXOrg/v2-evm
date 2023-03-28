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
  ConfigStorage__factory,
} from "../typechain";
import { getConfig } from "./utils/config";
import { MultiCall } from "@indexed-finance/multicall";

const BigNumber = ethers.BigNumber;
const config = getConfig();
const subAccountId = 1;

const formatUnits = ethers.utils.formatUnits;
const parseUnits = ethers.utils.parseUnits;
const ONE_USD = parseUnits("1", 30);

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
  const calculator = Calculator__factory.connect(config.calculator, deployer);
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
      balance: formatUnits(balances[1][config.tokens.plp].toString(), 18),
    },
    {
      token: "usdc",
      balance: formatUnits(balances[1][config.tokens.usdc].toString(), 6),
    },
    {
      token: "usdt",
      balance: formatUnits(balances[1][config.tokens.usdt].toString(), 6),
    },
    {
      token: "dai",
      balance: formatUnits(balances[1][config.tokens.dai].toString(), 18),
    },
    {
      token: "wbtc",
      balance: formatUnits(balances[1][config.tokens.wbtc].toString(), 8),
    },
    {
      token: "eth",
      balance: formatUnits(await provider.getBalance(deployer.address), 18),
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
      args: [deployer.address, subAccountId, ethAssetId],
    },
    // Free Collateral
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getFreeCollateral",
      args: [deployer.address, subAccountId, ethAssetId],
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
      args: [true],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getPLPValueE30",
      args: [true],
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
      function: "protocolFees",
      args: [config.tokens.usdc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "protocolFees",
      args: [config.tokens.usdt],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "protocolFees",
      args: [config.tokens.dai],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "protocolFees",
      args: [config.tokens.weth],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "protocolFees",
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
    // Positions
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "getPositionBySubAccount",
      args: [address],
    },
    // Market Configs
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "marketConfigs",
      args: [0],
    },
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "marketConfigs",
      args: [1],
    },
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "marketConfigs",
      args: [2],
    },
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "marketConfigs",
      args: [3],
    },
  ];
  const [
    ,
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
      plpTvl,
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
      positions,
      ethusdMarketConfig,
      btcusdMarketConfig,
      applusdMarketConfig,
      jpyusdMarketConfig,
    ],
  ] = await multi.multiCall(inputs);

  const inputs2 = [
    // Global Asset Class
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "getGlobalAssetClassByIndex",
      args: [0],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "getGlobalAssetClassByIndex",
      args: [1],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "getGlobalAssetClassByIndex",
      args: [2],
    },
  ];
  const [, [cryptoGlobalAssetClass, equityGlobalAssetClass, forexGlobalAssetClass]] = await multi.multiCall(inputs2);

  const adaptivePriceInputs = [
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracle.middleware,
      function: "getLatestAdaptivePrice",
      args: [
        ethAssetId,
        true,
        ethusdMarket.longPositionSize && ethusdMarket.shortPositionSize
          ? ethusdMarket.longPositionSize.sub(ethusdMarket.shortPositionSize)
          : 0,
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
        btcusdMarket.longPositionSize && btcusdMarket.shortPositionSize
          ? btcusdMarket.longPositionSize.sub(btcusdMarket.shortPositionSize)
          : 0,
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
        applusdMarket.longPositionSize && applusdMarket.shortPositionSize
          ? applusdMarket.longPositionSize.sub(applusdMarket.shortPositionSize)
          : 0,
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
        jpyusdMarket.longPositionSize && jpyusdMarket.shortPositionSize
          ? jpyusdMarket.longPositionSize.sub(jpyusdMarket.shortPositionSize)
          : 0,
        0,
        ethers.utils.parseUnits("3000000", 30),
      ],
    },
  ];
  const [blockNumber2, [ethusdAdaptivePrice, btcusdAdaptivePrice, applusdAdaptivePrice, jpyusdAdaptivePrice]] =
    await multi.multiCall(adaptivePriceInputs);

  console.log("=== Prices ===");
  console.log(formatUnits(usdcPrice._price, 30));
  console.log(formatUnits(usdtPrice?._price, 30));
  console.log(formatUnits(daiPrice?._price, 30));
  console.log(formatUnits(wethPrice?._price, 30));
  console.log(formatUnits(wbtcPrice?._price, 30));
  console.log(formatUnits(applePrice?._price, 30));
  console.log(formatUnits(jpyPrice?._price, 30));
  console.log("=== Adaptive Prices ===");
  console.log(formatUnits(ethusdAdaptivePrice._adaptivePrice, 30));
  console.log(formatUnits(btcusdAdaptivePrice._adaptivePrice, 30));
  console.log(formatUnits(applusdAdaptivePrice._adaptivePrice, 30));
  console.log(formatUnits(jpyusdAdaptivePrice._adaptivePrice, 30));
  console.log("=== Cross Margin Account ===");
  console.table({
    equity: formatUnits(equity, 30),
    freeCollateral: formatUnits(freeCollateral, 30),
  });
  console.log("=== Trader Balances ===");
  console.table({
    usdc: formatUnits(traderBalancesUsdc, 6),
    usdt: formatUnits(traderBalancesUsdt, 6),
    dai: formatUnits(traderBalancesDai, 18),
    weth: formatUnits(traderBalancesWeth, 18),
    wbtc: formatUnits(traderBalancesWbtc, 8),
  });
  console.log("=== PLP ===");
  console.table({
    plpTotalSupply: formatUnits(plpTotalSupply, 18),
    plpAum: formatUnits(plpAum, 30),
    plpPrice: plpAum.gt(0) ? formatUnits(plpAum.mul(ethers.utils.parseEther("1")).div(plpTotalSupply), 30) : 0,
    usdc: formatUnits(plpLiquidityUsdc, 6),
    usdt: formatUnits(plpLiquidityUsdt, 6),
    dai: formatUnits(plpLiquidityDai, 18),
    weth: formatUnits(plpLiquidityWeth, 18),
    wbtc: formatUnits(plpLiquidityWbtc, 8),
  });
  console.log("=== Asset Class ====");
  console.table({
    crypto: {
      reservedValue: formatUnits(assetClassCrypto.reserveValueE30, 30),
      sumBorrowingRate: assetClassCrypto.sumBorrowingRate,
      lastBorrowingTime: assetClassCrypto.lastBorrowingTime,
    },
    equity: {
      reservedValue: formatUnits(assetClassEquity.reserveValueE30, 30),
      sumBorrowingRate: assetClassEquity.sumBorrowingRate,
      lastBorrowingTime: assetClassEquity.lastBorrowingTime,
    },
    forex: {
      reservedValue: formatUnits(assetClassForex.reserveValueE30, 30),
      sumBorrowingRate: assetClassForex.sumBorrowingRate,
      lastBorrowingTime: assetClassForex.lastBorrowingTime,
    },
  });
  console.log("=== Platform Fees ===");
  console.table({
    usdc: formatUnits(feeUsdc, 6),
    usdt: formatUnits(feeUsdt, 6),
    dai: formatUnits(feeDai, 18),
    weth: formatUnits(feeWeth, 18),
    wbtc: formatUnits(feeWbtc, 8),
  });
  console.log("=== Dev Fees ===");
  console.table({
    usdc: formatUnits(devFeeUsdc, 6),
    usdt: formatUnits(devFeeUsdt, 6),
    dai: formatUnits(devFeeDai, 18),
    weth: formatUnits(devFeeWeth, 18),
    wbtc: formatUnits(devFeeWbtc, 8),
  });
  console.log("=== Markets ===");
  console.table({
    ETHUSD: {
      longPositionSize: formatUnits(ethusdMarket.longPositionSize, 30),
      longAvgPrice: formatUnits(ethusdMarket.longAvgPrice, 30),
      shortPositionSize: formatUnits(ethusdMarket.shortPositionSize, 30),
      shortAvgPrice: formatUnits(ethusdMarket.shortAvgPrice, 30),
    },
    BTCUSD: {
      longPositionSize: formatUnits(btcusdMarket.longPositionSize, 30),
      longAvgPrice: formatUnits(btcusdMarket.longAvgPrice, 30),
      shortPositionSize: formatUnits(btcusdMarket.shortPositionSize, 30),
      shortAvgPrice: formatUnits(btcusdMarket.shortAvgPrice, 30),
    },
    APPLUSD: {
      longPositionSize: formatUnits(applusdMarket.longPositionSize, 30),
      longAvgPrice: formatUnits(applusdMarket.longAvgPrice, 30),
      shortPositionSize: formatUnits(applusdMarket.shortPositionSize, 30),
      shortAvgPrice: formatUnits(applusdMarket.shortAvgPrice, 30),
    },
    JPYUSD: {
      longPositionSize: formatUnits(jpyusdMarket.longPositionSize, 30),
      longAvgPrice: formatUnits(jpyusdMarket.longAvgPrice, 30),
      shortPositionSize: formatUnits(jpyusdMarket.shortPositionSize, 30),
      shortAvgPrice: formatUnits(jpyusdMarket.shortAvgPrice, 30),
    },
  });

  const markets = [ethusdMarket, btcusdMarket, applusdMarket, jpyusdMarket];
  const oraclePrices = [wethPrice._price, wbtcPrice._price, applePrice._price, jpyPrice._price];
  const marketConfigs = [ethusdMarketConfig, btcusdMarketConfig, applusdMarketConfig, jpyusdMarketConfig];
  const globalAssetClasses = [cryptoGlobalAssetClass, equityGlobalAssetClass, forexGlobalAssetClass];

  const nextBorrowingRateInputs = [
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextBorrowingRate",
      args: [0, plpTvl],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextBorrowingRate",
      args: [1, plpTvl],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextBorrowingRate",
      args: [2, plpTvl],
    },
  ];
  const [, nextBorrowingRates] = await multi.multiCall(nextBorrowingRateInputs);
  const nextFundingRateInputs = [
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextFundingRate",
      args: [0],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextFundingRate",
      args: [1],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextFundingRate",
      args: [2],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextFundingRate",
      args: [3],
    },
  ];
  const [, nextFundingRates] = await multi.multiCall(nextFundingRateInputs);

  console.log("=== Positions ===");
  console.table(
    positions.map((each) => {
      const marketIndex = each.marketIndex.toNumber();
      const closePrice = calculateAdaptivePrice(
        markets[marketIndex].longPositionSize.sub(markets[marketIndex].shortPositionSize),
        marketConfigs[marketIndex].fundingRate.maxSkewScaleUSD,
        each.positionSizeE30.mul(-1),
        oraclePrices[marketIndex]
      );

      const borrowingFee = globalAssetClasses[marketConfigs[marketIndex].assetClass].sumBorrowingRate
        .add(nextBorrowingRates[marketConfigs[marketIndex].assetClass])
        .sub(each.entryBorrowingRate)
        .mul(each.reserveValueE30)
        .div(parseUnits("1", 18));

      const fundingFee = markets[marketIndex].currentFundingRate
        .add(nextFundingRates[marketIndex])
        .sub(each.entryFundingRate)
        .mul(each.positionSizeE30.abs())
        .div(parseUnits("1", 18))
        .mul(each.positionSizeE30.gt(0) ? -1 : 1);
      return {
        exposure: each.positionSizeE30.gt(0) ? "LONG" : "SHORT",
        size: formatUnits(each.positionSizeE30, 30),
        sizeInAsset: each.avgEntryPriceE30.gt(0)
          ? formatUnits(each.positionSizeE30.mul(parseUnits("1", 30)).div(each.avgEntryPriceE30), 30)
          : 0,
        reservedProfit: formatUnits(each.reserveValueE30, 30),
        averagePrice: formatUnits(each.avgEntryPriceE30, 30),
        markPrice: formatUnits(closePrice, 30),
        pnl: formatUnits(getPnL(closePrice, each.avgEntryPriceE30, each.positionSizeE30), 30),
        borrowingFee: formatUnits(borrowingFee, 30),
        fundingFee: formatUnits(fundingFee, 30),
        tradingFee: formatUnits(
          each.positionSizeE30.abs().mul(marketConfigs[marketIndex].decreasePositionFeeRateBPS).div(10000),
          30
        ),
        positionLeverage: equity.gt(0) ? formatUnits(each.positionSizeE30.mul(parseUnits("1", 30)).div(equity), 30) : 0,
      };
    })
  );
};

function calculateAdaptivePrice(
  marketSkew: BigNumber,
  maxSkewScaleUSD: BigNumber,
  sizeDelta: BigNumber,
  price: BigNumber
): BigNumber {
  const premium = marketSkew.mul(ONE_USD).div(maxSkewScaleUSD);
  const premiumAfter = marketSkew.add(sizeDelta).mul(ONE_USD).div(maxSkewScaleUSD);
  const premiumMedian = premium.add(premiumAfter).div(2);
  return price.mul(ONE_USD.add(premiumMedian)).div(ONE_USD);
}

function getPnL(closePrice: BigNumber, averagePrice: BigNumber, size: BigNumber): BigNumber {
  return closePrice.sub(averagePrice).mul(size).div(averagePrice);
}

export default func;
func.tags = ["ReadData"];
