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
  const BigNumber = ethers.BigNumber;

  const marketConfigs: Array<AddMarketConfig> = [
    {
      marketIndex: 3,
      assetId: ethers.utils.formatBytes32String("JPY"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 8,
      assetId: ethers.utils.formatBytes32String("EUR"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 10,
      assetId: ethers.utils.formatBytes32String("AUD"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 11,
      assetId: ethers.utils.formatBytes32String("GBP"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 26,
      assetId: ethers.utils.formatBytes32String("CHF"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 28,
      assetId: ethers.utils.formatBytes32String("CAD"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 29,
      assetId: ethers.utils.formatBytes32String("SGD"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 30,
      assetId: ethers.utils.formatBytes32String("CNH"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 31,
      assetId: ethers.utils.formatBytes32String("HKD"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 34,
      assetId: ethers.utils.formatBytes32String("DIX"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 250000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 46,
      assetId: ethers.utils.formatBytes32String("SEK"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 1,
      decreasePositionFeeRateBPS: 1,
      initialMarginFractionBPS: 10,
      maintenanceMarginFractionBPS: 5,
      maxProfitRateBPS: 500000,
      assetClass: 2,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("10000000", 30),
        maxFundingRate: ethers.utils.parseUnits("1", 18),
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
