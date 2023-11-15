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
  isAdaptiveFeeEnabled: boolean;
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

  const marketConfigs: Array<AddMarketConfig> = [
    {
      marketIndex: 0,
      assetId: ethers.utils.formatBytes32String("ETH"),
      maxLongPositionSize: ethers.utils.parseUnits("5500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("5500000", 30),
      increasePositionFeeRateBPS: 4, // 0.04%
      decreasePositionFeeRateBPS: 4, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 300000, // 3000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("2000000000", 30), // 2000 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 1,
      assetId: ethers.utils.formatBytes32String("BTC"),
      maxLongPositionSize: ethers.utils.parseUnits("6000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("6000000", 30),
      increasePositionFeeRateBPS: 4, // 0.04%
      decreasePositionFeeRateBPS: 4, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 300000, // 3000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("3000000000", 30), // 3000 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: false,
    },
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  await validate(configStorage, marketConfigs);

  const owner = await configStorage.owner();

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
