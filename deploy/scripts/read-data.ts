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
} from "../../typechain";
import { getConfig } from "../utils/config";
import { getPricesFromPyth } from "../utils/price";
import { MultiCall } from "@indexed-finance/multicall";

const BigNumber = ethers.BigNumber;
const config = getConfig();
const subAccountId = 1;

const formatUnits = ethers.utils.formatUnits;
const parseUnits = ethers.utils.parseUnits;
const ONE_USD = parseUnits("1", 30);

const ethAssetId = ethers.utils.formatBytes32String("ETH");
const wbtcAssetId = ethers.utils.formatBytes32String("BTC");
const usdcAssetId = ethers.utils.formatBytes32String("USDC");
const usdtAssetId = ethers.utils.formatBytes32String("USDT");
const daiAssetId = ethers.utils.formatBytes32String("DAI");
const appleAssetId = ethers.utils.formatBytes32String("AAPL");
const jpyAssetId = ethers.utils.formatBytes32String("JPY");
const glpAssetId = ethers.utils.formatBytes32String("GLP");

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const address = BigNumber.from(deployer.address).xor(subAccountId).toHexString();
  const calculator = Calculator__factory.connect(config.calculator, deployer);
  const provider = ethers.provider;
  const multi = new MultiCall(provider);

  const balances = await multi.getBalances(
    [
      config.tokens.usdc,
      config.tokens.usdt,
      config.tokens.dai,
      config.tokens.wbtc,
      config.tokens.hlp,
      config.tokens.sglp,
    ],
    deployer.address
  );
  console.log("=== Wallet Balances ===");
  console.table([
    {
      token: "plp",
      balance: formatUnits(balances[1][config.tokens.hlp].toString(), 18),
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
    {
      token: "sglp",
      balance: formatUnits(balances[1][config.tokens.sglp].toString(), 18),
    },
  ]);

  const inputs = [
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [address, config.tokens.usdc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [address, config.tokens.usdt],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [address, config.tokens.dai],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [address, config.tokens.weth],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [address, config.tokens.wbtc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "traderBalances",
      args: [address, config.tokens.sglp],
    },
    // Equity
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getEquity",
      args: [address, 0, ethAssetId],
    },
    // Free Collateral
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getFreeCollateral",
      args: [address, 0, ethAssetId],
    },
    // IMR
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getIMR",
      args: [address],
    },
    // MMR
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getMMR",
      args: [address],
    },
    // Prices
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [usdcAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [usdtAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [daiAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [ethAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [wbtcAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [appleAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [jpyAssetId, false],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestPrice",
      args: [glpAssetId, false],
    },
    // PLP
    {
      interface: PLPv2__factory.abi,
      target: config.tokens.hlp,
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
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "plpLiquidity",
      args: [config.tokens.sglp],
    },
    // Global Markets
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "markets",
      args: [0],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "markets",
      args: [1],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "markets",
      args: [2],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "markets",
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
      traderBalancesSglp,
      equity,
      freeCollateral,
      imr,
      mmr,
      usdcPrice,
      usdtPrice,
      daiPrice,
      wethPrice,
      wbtcPrice,
      applePrice,
      jpyPrice,
      sglpPrice,
      plpTotalSupply,
      plpAum,
      plpTvl,
      plpLiquidityUsdc,
      plpLiquidityUsdt,
      plpLiquidityDai,
      plpLiquidityWeth,
      plpLiquidityWbtc,
      plpLiquiditySglp,
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

  const feeInputs = [
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
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "protocolFees",
      args: [config.tokens.sglp],
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
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "devFees",
      args: [config.tokens.sglp],
    },
  ];
  const [
    ,
    [
      feeUsdc,
      feeUsdt,
      feeDai,
      feeWeth,
      feeWbtc,
      feeSglp,
      devFeeUsdc,
      devFeeUsdt,
      devFeeDai,
      devFeeWeth,
      devFeeWbtc,
      devFeeSglp,
    ],
  ] = await multi.multiCall(feeInputs);

  const inputs2 = [
    // Global Asset Class
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "getAssetClassByIndex",
      args: [0],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "getAssetClassByIndex",
      args: [1],
    },
    {
      interface: PerpStorage__factory.abi,
      target: config.storages.perp,
      function: "getAssetClassByIndex",
      args: [2],
    },
    // Trader Tokens
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "getTraderTokens",
      args: [address],
    },
  ];
  const [, [cryptoGlobalAssetClass, equityGlobalAssetClass, forexGlobalAssetClass, traderTokens]] =
    await multi.multiCall(inputs2);

  const adaptivePriceInputs = [
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestAdaptivePrice",
      args: [
        ethAssetId,
        true,
        ethusdMarket.longPositionSize && ethusdMarket.shortPositionSize
          ? ethusdMarket.longPositionSize.sub(ethusdMarket.shortPositionSize)
          : 0,
        0,
        ethers.utils.parseUnits("3000000", 30),
        0,
      ],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestAdaptivePrice",
      args: [
        wbtcAssetId,
        true,
        btcusdMarket.longPositionSize && btcusdMarket.shortPositionSize
          ? btcusdMarket.longPositionSize.sub(btcusdMarket.shortPositionSize)
          : 0,
        0,
        ethers.utils.parseUnits("3000000", 30),
        0,
      ],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestAdaptivePrice",
      args: [
        appleAssetId,
        true,
        applusdMarket.longPositionSize && applusdMarket.shortPositionSize
          ? applusdMarket.longPositionSize.sub(applusdMarket.shortPositionSize)
          : 0,
        0,
        ethers.utils.parseUnits("3000000", 30),
        0,
      ],
    },
    {
      interface: OracleMiddleware__factory.abi,
      target: config.oracles.middleware,
      function: "unsafeGetLatestAdaptivePrice",
      args: [
        jpyAssetId,
        true,
        jpyusdMarket.longPositionSize && jpyusdMarket.shortPositionSize
          ? jpyusdMarket.longPositionSize.sub(jpyusdMarket.shortPositionSize)
          : 0,
        0,
        ethers.utils.parseUnits("3000000", 30),
        0,
      ],
    },
  ];
  const [blockNumber2, [ethusdAdaptivePrice, btcusdAdaptivePrice, applusdAdaptivePrice, jpyusdAdaptivePrice]] =
    await multi.multiCall(adaptivePriceInputs);

  const accountDebtRequests = [
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "tradingFeeDebt",
      args: [address],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "borrowingFeeDebt",
      args: [address],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fundingFeeDebt",
      args: [address],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "lossDebt",
      args: [address],
    },
  ];
  const [, [tradingFeeDebt, borrowingFeeDebt, fundingFeeDebt, lossDebt]] = await multi.multiCall(accountDebtRequests);

  console.log("=== Prices ===");
  console.log(formatUnits(usdcPrice._price, 30));
  console.log(formatUnits(usdtPrice?._price, 30));
  console.log(formatUnits(daiPrice?._price, 30));
  console.log(formatUnits(wethPrice?._price, 30));
  console.log(formatUnits(wbtcPrice?._price, 30));
  console.log(formatUnits(applePrice?._price, 30));
  console.log(formatUnits(jpyPrice?._price, 30));
  console.log(formatUnits(sglpPrice?._price, 30));
  console.log("=== Adaptive Prices ===");

  console.log(formatUnits(ethusdAdaptivePrice._adaptivePrice, 30));
  console.log(formatUnits(btcusdAdaptivePrice._adaptivePrice, 30));
  console.log(formatUnits(applusdAdaptivePrice._adaptivePrice, 30));
  console.log(formatUnits(jpyusdAdaptivePrice._adaptivePrice, 30));
  console.log("=== Cross Margin Account ===");
  console.table({
    equity: formatUnits(equity, 30),
    freeCollateral: formatUnits(freeCollateral, 30),
    imr: formatUnits(imr, 30),
    mmr: formatUnits(mmr, 30),
  });
  console.log("=== Trader Balances ===");
  console.table({
    usdc: formatUnits(traderBalancesUsdc, 6),
    usdt: formatUnits(traderBalancesUsdt, 6),
    dai: formatUnits(traderBalancesDai, 18),
    weth: formatUnits(traderBalancesWeth, 18),
    wbtc: formatUnits(traderBalancesWbtc, 8),
    sglp: formatUnits(traderBalancesSglp, 18),
  });
  console.log("=== Trader Debts ===");
  console.table({
    tradingFeeDebt: formatUnits(tradingFeeDebt, 30),
    borrowingFeeDebt: formatUnits(borrowingFeeDebt, 30),
    fundingFeeDebt: formatUnits(fundingFeeDebt, 30),
    lossDebt: formatUnits(lossDebt, 30),
  });
  console.log("=== Trader Tokens ===");
  console.log(traderTokens);
  console.log("=== PLP ===");
  console.table({
    plpTotalSupply: formatUnits(plpTotalSupply, 18),
    plpAum: plpAum ? formatUnits(plpAum, 30) : 0,
    plpPrice:
      plpAum && plpAum.gt(0) ? formatUnits(plpAum.mul(ethers.utils.parseEther("1")).div(plpTotalSupply), 30) : 0,
    usdc: formatUnits(plpLiquidityUsdc, 6),
    usdt: formatUnits(plpLiquidityUsdt, 6),
    dai: formatUnits(plpLiquidityDai, 18),
    weth: formatUnits(plpLiquidityWeth, 18),
    wbtc: formatUnits(plpLiquidityWbtc, 8),
    sglp: formatUnits(plpLiquiditySglp, 18),
  });
  console.log("=== Asset Class ====");
  console.table({
    crypto: {
      reservedValue: formatUnits(cryptoGlobalAssetClass.reserveValueE30, 30),
      sumBorrowingRate: cryptoGlobalAssetClass.sumBorrowingRate,
      lastBorrowingTime: cryptoGlobalAssetClass.lastBorrowingTime,
    },
    equity: {
      reservedValue: formatUnits(equityGlobalAssetClass.reserveValueE30, 30),
      sumBorrowingRate: equityGlobalAssetClass.sumBorrowingRate,
      lastBorrowingTime: equityGlobalAssetClass.lastBorrowingTime,
    },
    forex: {
      reservedValue: formatUnits(forexGlobalAssetClass.reserveValueE30, 30),
      sumBorrowingRate: forexGlobalAssetClass.sumBorrowingRate,
      lastBorrowingTime: forexGlobalAssetClass.lastBorrowingTime,
    },
  });
  console.log("=== Platform Fees ===");
  console.table({
    usdc: formatUnits(feeUsdc, 6),
    usdt: formatUnits(feeUsdt, 6),
    dai: formatUnits(feeDai, 18),
    weth: formatUnits(feeWeth, 18),
    wbtc: formatUnits(feeWbtc, 8),
    sglp: formatUnits(feeSglp, 18),
  });
  console.log("=== Dev Fees ===");
  console.table({
    usdc: formatUnits(devFeeUsdc, 6),
    usdt: formatUnits(devFeeUsdt, 6),
    dai: formatUnits(devFeeDai, 18),
    weth: formatUnits(devFeeWeth, 18),
    wbtc: formatUnits(devFeeWbtc, 8),
    sglp: formatUnits(devFeeSglp, 18),
  });
  console.log("=== Markets ===");
  console.table({
    ETHUSD: {
      longPositionSize: formatUnits(ethusdMarket.longPositionSize, 30),
      shortPositionSize: formatUnits(ethusdMarket.shortPositionSize, 30),
    },
    BTCUSD: {
      longPositionSize: formatUnits(btcusdMarket.longPositionSize, 30),
      shortPositionSize: formatUnits(btcusdMarket.shortPositionSize, 30),
    },
    APPLUSD: {
      longPositionSize: formatUnits(applusdMarket.longPositionSize, 30),
      shortPositionSize: formatUnits(applusdMarket.shortPositionSize, 30),
    },
    JPYUSD: {
      longPositionSize: formatUnits(jpyusdMarket.longPositionSize, 30),
      shortPositionSize: formatUnits(jpyusdMarket.shortPositionSize, 30),
    },
  });

  const markets = [ethusdMarket, btcusdMarket, applusdMarket, jpyusdMarket];
  const [rawEthPrice, rawBtcPrice, rawUsdcPrice, rawUsdtPrice, rawDaiPrice, rawAAPLPrice, rawJpyPrice] =
    await getPricesFromPyth();
  const oraclePrices = [rawEthPrice, rawBtcPrice, rawAAPLPrice, rawJpyPrice];
  const marketConfigs = [ethusdMarketConfig, btcusdMarketConfig, applusdMarketConfig, jpyusdMarketConfig];
  const globalAssetClasses = [cryptoGlobalAssetClass, equityGlobalAssetClass, forexGlobalAssetClass];

  const nextBorrowingRateInputs = [
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextBorrowingRate",
      args: [0, plpTvl || 0],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextBorrowingRate",
      args: [1, plpTvl || 0],
    },
    {
      interface: Calculator__factory.abi,
      target: config.calculator,
      function: "getNextBorrowingRate",
      args: [2, plpTvl || 0],
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
        BigNumber.from(oraclePrices[marketIndex] * 1e8).mul(ethers.utils.parseUnits("1", 22))
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
  console.log("marketSkew", marketSkew);
  console.log("maxSkewScaleUSD", maxSkewScaleUSD);
  console.log("sizeDelta", sizeDelta);
  console.log("price", price);
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
