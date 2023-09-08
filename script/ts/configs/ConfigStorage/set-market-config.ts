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
  marketIndex: number;
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
      assetId: ethers.utils.formatBytes32String("ETH"),
      maxLongPositionSize: ethers.utils.parseUnits("5000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("5000000", 30),
      increasePositionFeeRateBPS: 4, // 0.04%
      decreasePositionFeeRateBPS: 4, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("2000000000", 30), // 2000 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
    },
    {
      marketIndex: 1,
      assetId: ethers.utils.formatBytes32String("BTC"),
      maxLongPositionSize: ethers.utils.parseUnits("5000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("5000000", 30),
      increasePositionFeeRateBPS: 4, // 0.04%
      decreasePositionFeeRateBPS: 4, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("3000000000", 30), // 3000 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
    },
    {
      marketIndex: 2,
      assetId: ethers.utils.formatBytes32String("AAPL"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 5,
      assetId: ethers.utils.formatBytes32String("AMZN"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 6,
      assetId: ethers.utils.formatBytes32String("MSFT"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 7,
      assetId: ethers.utils.formatBytes32String("TSLA"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 12,
      assetId: ethers.utils.formatBytes32String("ADA"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
    },
    {
      marketIndex: 13,
      assetId: ethers.utils.formatBytes32String("MATIC"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
    },
    {
      marketIndex: 14,
      assetId: ethers.utils.formatBytes32String("SUI"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 15,
      assetId: ethers.utils.formatBytes32String("ARB"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 16,
      assetId: ethers.utils.formatBytes32String("OP"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 17,
      assetId: ethers.utils.formatBytes32String("LTC"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 18,
      assetId: ethers.utils.formatBytes32String("COIN"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("500000000", 30), // 500 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 19,
      assetId: ethers.utils.formatBytes32String("GOOG"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 20,
      assetId: ethers.utils.formatBytes32String("BNB"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 21,
      assetId: ethers.utils.formatBytes32String("SOL"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 22,
      assetId: ethers.utils.formatBytes32String("QQQ"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 23,
      assetId: ethers.utils.formatBytes32String("XRP"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("500000000", 30), // 500 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 24,
      assetId: ethers.utils.formatBytes32String("NVDA"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: false,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
    },
    {
      marketIndex: 25,
      assetId: ethers.utils.formatBytes32String("LINK"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
    },
    {
      marketIndex: 27,
      assetId: ethers.utils.formatBytes32String("DOGE"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 100% per day
      },
    },
  ];

  const marketConfigs: Array<AddMarketConfig> = rawInputs.map((each) => {
    return {
      marketIndex: each.marketIndex,
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
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  await validate(configStorage, marketConfigs);

  console.log("[configs/ConfigStorage] Setting market config...");
  for (let i = 0; i < marketConfigs.length; i++) {
    console.log(
      `[configs/ConfigStorage] Setting ${ethers.utils.parseBytes32String(marketConfigs[i].assetId)} market config...`
    );
    if (compareAddress(owner, config.safe)) {
      const tx = await safeWrapper.proposeTransaction(
        configStorage.address,
        0,
        configStorage.interface.encodeFunctionData("setMarketConfig", [marketConfigs[i].marketIndex, marketConfigs[i]])
      );
      console.log(`[configs/ConfigStorage] Tx: ${tx}`);
    } else {
      const tx = await configStorage.setMarketConfig(marketConfigs[i].marketIndex, marketConfigs[i]);
      console.log(`[configs/ConfigStorage] Tx: ${tx.hash}`);
      await tx.wait();
    }
  }
  console.log("[configs/ConfigStorage] Finished");
}

async function validate(configStorage: ConfigStorage, marketConfig: Array<AddMarketConfig>) {
  await marketConfig.forEach(async (each) => {
    const existingMarketConfig = await configStorage.marketConfigs(each.marketIndex);
    if (existingMarketConfig.assetId !== each.assetId) {
      throw `marketIndex ${each.marketIndex} wrong asset id`;
    }
    if (each.increasePositionFeeRateBPS > MAX_TRADING_FEE || each.decreasePositionFeeRateBPS > MAX_TRADING_FEE) {
      throw `marketIndex ${each.marketIndex}: ${each.increasePositionFeeRateBPS} ${each.decreasePositionFeeRateBPS} bad tradeing fee`;
    }
    if (each.initialMarginFractionBPS < MIN_IMF) {
      throw `marketIndex ${each.marketIndex}: ${each.initialMarginFractionBPS} bad imf`;
    }
    if (each.maintenanceMarginFractionBPS < MIN_MMF) {
      throw `marketIndex ${each.marketIndex}: ${each.maintenanceMarginFractionBPS} bad mmf`;
    }
    if (each.maxProfitRateBPS > MAX_PROFIT_RATE) {
      throw `marketIndex ${each.marketIndex}: ${each.maxProfitRateBPS} bad max profit`;
    }
    if (each.fundingRate.maxSkewScaleUSD.gt(MAX_SKEW_SCALE)) {
      throw `marketIndex ${each.marketIndex}: ${each.fundingRate.maxSkewScaleUSD} bad max skew scale`;
    }
    if (each.fundingRate.maxFundingRate.gt(MAX_FUNDING_RATE)) {
      throw `marketIndex ${each.marketIndex}: ${each.fundingRate.maxFundingRate} bad max funding rate`;
    }
    if (each.maxLongPositionSize.gt(MAX_OI) || each.maxShortPositionSize.gt(MAX_OI)) {
      throw `marketIndex ${each.marketIndex}: ${each.maxLongPositionSize} ${each.maxShortPositionSize} bad max oi`;
    }
  });
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
