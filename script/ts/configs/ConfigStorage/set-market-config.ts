import { ethers } from "ethers";
import { ConfigStorage__factory, TradeHelper__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import assetClasses from "../../entities/asset-classes";
import SafeWrapper from "../../wrappers/SafeWrapper";

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

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const marketConfigs: Array<AddMarketConfig> = [
    {
      marketIndex: 0,
      assetId: ethers.utils.formatBytes32String("ETH"),
      maxLongPositionSize: ethers.utils.parseUnits("5500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("5500000", 30),
      increasePositionFeeRateBPS: 2, // 0.02%
      decreasePositionFeeRateBPS: 2, // 0.02%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 350000, // 3500%
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
      increasePositionFeeRateBPS: 2, // 0.02%
      decreasePositionFeeRateBPS: 2, // 0.02%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 350000, // 3500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("3000000000", 30), // 3000 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 2,
      assetId: ethers.utils.formatBytes32String("AAPL"),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 10% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 3,
      assetId: ethers.utils.formatBytes32String("JPY"),
      maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
      increasePositionFeeRateBPS: 1, // 0.01%
      decreasePositionFeeRateBPS: 1, // 0.01%
      initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
      maintenanceMarginFractionBPS: 5, // MMF = 0.05%
      maxProfitRateBPS: 500000, // 5000%
      assetClass: assetClasses.forex,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 4,
      assetId: ethers.utils.formatBytes32String("XAU"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 3, // 0.03%
      decreasePositionFeeRateBPS: 3, // 0.03%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 75000, // 750%
      assetClass: assetClasses.commodities,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 5,
      assetId: ethers.utils.formatBytes32String("AMZN"),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 10% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 6,
      assetId: ethers.utils.formatBytes32String("MSFT"),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 10% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 7,
      assetId: ethers.utils.formatBytes32String("TSLA"),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.equity,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 10% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 8,
      assetId: ethers.utils.formatBytes32String("EUR"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 1, // 0.01%
      decreasePositionFeeRateBPS: 1, // 0.01%
      initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
      maintenanceMarginFractionBPS: 5, // MMF = 0.05%
      maxProfitRateBPS: 500000, // 5000%
      assetClass: assetClasses.forex,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 9,
      assetId: ethers.utils.formatBytes32String("XAG"),
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
      increasePositionFeeRateBPS: 3, // 0.03%
      decreasePositionFeeRateBPS: 3, // 0.03%
      initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
      maintenanceMarginFractionBPS: 100, // MMF = 1%
      maxProfitRateBPS: 75000, // 750%
      assetClass: assetClasses.commodities,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
      },
      isAdaptiveFeeEnabled: false,
    },
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const tradeHelper = TradeHelper__factory.connect(config.helpers.trade, deployer);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  console.log("[ConfigStorage] Setting market config...");
  for (let i = 0; i < marketConfigs.length; i++) {
    console.log(
      `[ConfigStorage] Setting ${ethers.utils.parseBytes32String(marketConfigs[i].assetId)} market config...`
    );
    const existingMarketConfig = await configStorage.marketConfigs(marketConfigs[i].marketIndex);
    if (existingMarketConfig.assetId !== marketConfigs[i].assetId) {
      console.log(`marketIndex ${marketConfigs[i].marketIndex} wrong asset id`);
      throw "bad asset id";
    }

    await (
      await configStorage.setMarketConfig(
        marketConfigs[i].marketIndex,
        marketConfigs[i],
        marketConfigs[i].isAdaptiveFeeEnabled
      )
    ).wait();
  }
  console.log("[ConfigStorage] Finished");
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
