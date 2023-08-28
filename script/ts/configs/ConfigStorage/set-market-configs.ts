import { ethers } from "ethers";
import { ConfigStorage, ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import assetClasses from "../../entities/asset-classes";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

const MAX_TRADING_FEE = 3000; // 0.3%
const MIN_IMF = 10; // 0.1%
const MIN_MMF = 5; // 0.05%
const MAX_PROFIT_RATE = 500000; // 50 BPS or 5000% or 50x
const MAX_SKEW_SCALE = ethers.utils.parseUnits("10000000000", 30); // 10B USD
const MAX_FUNDING_RATE = ethers.utils.parseUnits("36", 18); // 3600% per day
const MAX_OI = ethers.utils.parseUnits("20000000", 30); // 20M USD

type AddMarketConfig = {
  assetId: string;
  increasePositionFeeRateBPS: number;
  decreasePositionFeeRateBPS: number;
  initialMarginFractionBPS: number;
  maintenanceMarginFractionBPS: number;
  maxProfitRateBPS: number;
  assetClass: number;
  allowIncreasePosition: boolean;
  active: boolean;
  fundingRate: {
    maxSkewScaleUSD: ethers.BigNumber;
    maxFundingRate: ethers.BigNumber;
  };
  maxLongPositionSize: ethers.BigNumber;
  maxShortPositionSize: ethers.BigNumber;
};

type RawMarketConfig = {
  marketIndex: number;
  assetId: string;
  increasePositionFeeRateBPS: number;
  decreasePositionFeeRateBPS: number;
  initialMarginFractionBPS: number;
  maintenanceMarginFractionBPS: number;
  maxProfitRateBPS: number;
  assetClass: string;
  allowIncreasePosition: boolean;
  active: boolean;
  maxSkewScaleUSD: number;
  maxFundingRate: number;
  maxLongPositionSize: number;
  maxShortPositionSize: number;
};

const ASSET_CLASS_MAP: { [key: string]: number } = {
  CRYPTO: assetClasses.crypto,
  COMMODITY: assetClasses.commodities,
  FOREX: assetClasses.forex,
  EQUITY: assetClasses.equity,
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const rawInputs: Array<RawMarketConfig> = [
    {
      marketIndex: 0,
      maxLongPositionSize: 5000000,
      maxShortPositionSize: 5000000,
      increasePositionFeeRateBPS: 0.0004,
      decreasePositionFeeRateBPS: 0.0004,
      initialMarginFractionBPS: 0.01,
      maintenanceMarginFractionBPS: 0.005,
      maxProfitRateBPS: 20,
      assetClass: "CRYPTO",
      maxFundingRate: 8,
      maxSkewScaleUSD: 2000000000,
      assetId: "ETH",
      allowIncreasePosition: true,
      active: true,
    },
    // {
    //   marketIndex: 1,
    //   maxLongPositionSize: 5000000,
    //   maxShortPositionSize: 5000000,
    //   increasePositionFeeRateBPS: 0.0004,
    //   decreasePositionFeeRateBPS: 0.0004,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 3000000000,
    //   assetId: "BTC",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 2,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "AAPL",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 3,
    //   maxLongPositionSize: 3000000,
    //   maxShortPositionSize: 3000000,
    //   increasePositionFeeRateBPS: 0.0001,
    //   decreasePositionFeeRateBPS: 0.0001,
    //   initialMarginFractionBPS: 0.001,
    //   maintenanceMarginFractionBPS: 0.0005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "FOREX",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "JPY",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 4,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 8,
    //   assetClass: "COMMODITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "XAU",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 5,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "AMZN",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 6,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "MSFT",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 7,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "TSLA",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 8,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0001,
    //   decreasePositionFeeRateBPS: 0.0001,
    //   initialMarginFractionBPS: 0.001,
    //   maintenanceMarginFractionBPS: 0.0005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "FOREX",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "EUR",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 9,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 8,
    //   assetClass: "COMMODITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "XAG",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 10,
    //   maxLongPositionSize: 3000000,
    //   maxShortPositionSize: 3000000,
    //   increasePositionFeeRateBPS: 0.0001,
    //   decreasePositionFeeRateBPS: 0.0001,
    //   initialMarginFractionBPS: 0.001,
    //   maintenanceMarginFractionBPS: 0.0005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "FOREX",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "AUD",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 11,
    //   maxLongPositionSize: 3000000,
    //   maxShortPositionSize: 3000000,
    //   increasePositionFeeRateBPS: 0.0001,
    //   decreasePositionFeeRateBPS: 0.0001,
    //   initialMarginFractionBPS: 0.001,
    //   maintenanceMarginFractionBPS: 0.0005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "FOREX",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "GBP",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 12,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 200000000,
    //   assetId: "ADA",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 13,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 200000000,
    //   assetId: "MATIC",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 14,
    //   maxLongPositionSize: 1000000,
    //   maxShortPositionSize: 1000000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 100000000,
    //   assetId: "SUI",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 15,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 100000000,
    //   assetId: "ARB",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 16,
    //   maxLongPositionSize: 1000000,
    //   maxShortPositionSize: 1000000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 100000000,
    //   assetId: "OP",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 17,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 100000000,
    //   assetId: "LTC",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 18,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 500000000,
    //   assetId: "COIN",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 19,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "GOOG",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 20,
    //   maxLongPositionSize: 1000000,
    //   maxShortPositionSize: 1000000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 100000000,
    //   assetId: "BNB",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 21,
    //   maxLongPositionSize: 1000000,
    //   maxShortPositionSize: 1000000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 100000000,
    //   assetId: "SOL",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 22,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "QQQ",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 23,
    //   maxLongPositionSize: 1000000,
    //   maxShortPositionSize: 1000000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 500000000,
    //   assetId: "XRP",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 24,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0005,
    //   decreasePositionFeeRateBPS: 0.0005,
    //   initialMarginFractionBPS: 0.02,
    //   maintenanceMarginFractionBPS: 0.01,
    //   maxProfitRateBPS: 10,
    //   assetClass: "EQUITY",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "NVDA",
    //   allowIncreasePosition: false,
    //   active: true,
    // },
    // {
    //   marketIndex: 25,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 100000000,
    //   assetId: "LINK",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 26,
    //   maxLongPositionSize: 3000000,
    //   maxShortPositionSize: 3000000,
    //   increasePositionFeeRateBPS: 0.0001,
    //   decreasePositionFeeRateBPS: 0.0001,
    //   initialMarginFractionBPS: 0.001,
    //   maintenanceMarginFractionBPS: 0.0005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "FOREX",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "CHF",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 27,
    //   maxLongPositionSize: 2500000,
    //   maxShortPositionSize: 2500000,
    //   increasePositionFeeRateBPS: 0.0007,
    //   decreasePositionFeeRateBPS: 0.0007,
    //   initialMarginFractionBPS: 0.01,
    //   maintenanceMarginFractionBPS: 0.005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "CRYPTO",
    //   maxFundingRate: 8,
    //   maxSkewScaleUSD: 200000000,
    //   assetId: "DOGE",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 28,
    //   maxLongPositionSize: 3000000,
    //   maxShortPositionSize: 3000000,
    //   increasePositionFeeRateBPS: 0.0001,
    //   decreasePositionFeeRateBPS: 0.0001,
    //   initialMarginFractionBPS: 0.001,
    //   maintenanceMarginFractionBPS: 0.0005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "FOREX",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "CAD",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
    // {
    //   marketIndex: 29,
    //   maxLongPositionSize: 3000000,
    //   maxShortPositionSize: 3000000,
    //   increasePositionFeeRateBPS: 0.0001,
    //   decreasePositionFeeRateBPS: 0.0001,
    //   initialMarginFractionBPS: 0.001,
    //   maintenanceMarginFractionBPS: 0.0005,
    //   maxProfitRateBPS: 20,
    //   assetClass: "FOREX",
    //   maxFundingRate: 1,
    //   maxSkewScaleUSD: 1000000000,
    //   assetId: "SGD",
    //   allowIncreasePosition: true,
    //   active: true,
    // },
  ];

  const marketConfigs: Array<AddMarketConfig> = rawInputs.map((each) => {
    return {
      assetId: ethers.utils.formatBytes32String(each.assetId),
      increasePositionFeeRateBPS: each.increasePositionFeeRateBPS * 1e4,
      decreasePositionFeeRateBPS: each.decreasePositionFeeRateBPS * 1e4,
      initialMarginFractionBPS: each.initialMarginFractionBPS * 1e4,
      maintenanceMarginFractionBPS: each.maintenanceMarginFractionBPS * 1e4,
      maxProfitRateBPS: each.maxProfitRateBPS * 1e4,
      assetClass: ASSET_CLASS_MAP[each.assetClass],
      allowIncreasePosition: each.allowIncreasePosition,
      active: each.active,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits(each.maxSkewScaleUSD.toString(), 30),
        maxFundingRate: ethers.utils.parseUnits(each.maxFundingRate.toString(), 18),
      },
      maxLongPositionSize: ethers.utils.parseUnits(each.maxLongPositionSize.toString(), 30),
      maxShortPositionSize: ethers.utils.parseUnits(each.maxShortPositionSize.toString(), 30),
    };
  });

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const safeWrapper = new SafeWrapper(chainId, deployer);
  const owner = await configStorage.owner();

  await validate(configStorage, marketConfigs);

  console.log("[configs/ConfigStorage] Setting market config...");
  if (compareAddress(owner, config.safe)) {
    // const tx = await safeWrapper.proposeTransaction(
    //   configStorage.address,
    //   0,
    //   configStorage.interface.encodeFunctionData("setMarketConfigs", [
    //     marketConfigs.map((each) => each.marketIndex),
    //     marketConfigs,
    //   ])
    // );
    // console.log(`[configs/ConfigStorage] Tx: ${tx}`);
  } else {
    const tx = await configStorage.setMarketConfigs([0], marketConfigs, { gasLimit: 10000000 });
    console.log(`[configs/ConfigStorage] Tx: ${tx.hash}`);
    await tx.wait();
  }
}
console.log("[configs/ConfigStorage] Finished");

async function validate(configStorage: ConfigStorage, marketConfig: Array<AddMarketConfig>) {
  // await marketConfig.forEach(async (each) => {
  //   const existingMarketConfig = await configStorage.marketConfigs(each.marketIndex);
  //   if (existingMarketConfig.assetId !== each.assetId) {
  //     throw `marketIndex ${each.marketIndex} wrong asset id`;
  //   }
  //   if (each.increasePositionFeeRateBPS > MAX_TRADING_FEE || each.decreasePositionFeeRateBPS > MAX_TRADING_FEE) {
  //     throw `marketIndex ${each.marketIndex}: ${each.increasePositionFeeRateBPS} ${each.decreasePositionFeeRateBPS} bad tradeing fee`;
  //   }
  //   if (each.initialMarginFractionBPS < MIN_IMF) {
  //     throw `marketIndex ${each.marketIndex}: ${each.initialMarginFractionBPS} bad imf`;
  //   }
  //   if (each.maintenanceMarginFractionBPS < MIN_MMF) {
  //     throw `marketIndex ${each.marketIndex}: ${each.maintenanceMarginFractionBPS} bad mmf`;
  //   }
  //   if (each.maxProfitRateBPS > MAX_PROFIT_RATE) {
  //     throw `marketIndex ${each.marketIndex}: ${each.maxProfitRateBPS} bad max profit`;
  //   }
  //   if (each.fundingRate.maxSkewScaleUSD.gt(MAX_SKEW_SCALE)) {
  //     throw `marketIndex ${each.marketIndex}: ${each.fundingRate.maxSkewScaleUSD} bad max skew scale`;
  //   }
  //   if (each.fundingRate.maxFundingRate.gt(MAX_FUNDING_RATE)) {
  //     throw `marketIndex ${each.marketIndex}: ${each.fundingRate.maxFundingRate} bad max funding rate`;
  //   }
  //   if (each.maxLongPositionSize.gt(MAX_OI) || each.maxShortPositionSize.gt(MAX_OI)) {
  //     throw `marketIndex ${each.marketIndex}: ${each.maxLongPositionSize} ${each.maxShortPositionSize} bad max oi`;
  //   }
  // });
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
