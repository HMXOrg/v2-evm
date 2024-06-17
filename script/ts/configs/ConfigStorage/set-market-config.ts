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
      marketIndex: 15,
      assetId: ethers.utils.formatBytes32String("ARB"),
      maxLongPositionSize: ethers.utils.parseUnits("800000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("800000", 30),
      increasePositionFeeRateBPS: 5,
      decreasePositionFeeRateBPS: 5,
      initialMarginFractionBPS: 400,
      maintenanceMarginFractionBPS: 50,
      maxProfitRateBPS: 100000,
      assetClass: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30),
        maxFundingRate: ethers.utils.parseUnits("8", 18),
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 16,
      assetId: ethers.utils.formatBytes32String("OP"),
      maxLongPositionSize: ethers.utils.parseUnits("800000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("800000", 30),
      increasePositionFeeRateBPS: 5,
      decreasePositionFeeRateBPS: 5,
      initialMarginFractionBPS: 400,
      maintenanceMarginFractionBPS: 50,
      maxProfitRateBPS: 100000,
      assetClass: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30),
        maxFundingRate: ethers.utils.parseUnits("8", 18),
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 25,
      assetId: ethers.utils.formatBytes32String("LINK"),
      maxLongPositionSize: ethers.utils.parseUnits("800000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("800000", 30),
      increasePositionFeeRateBPS: 5,
      decreasePositionFeeRateBPS: 5,
      initialMarginFractionBPS: 400,
      maintenanceMarginFractionBPS: 50,
      maxProfitRateBPS: 100000,
      assetClass: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30),
        maxFundingRate: ethers.utils.parseUnits("8", 18),
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 27,
      assetId: ethers.utils.formatBytes32String("DOGE"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 5,
      decreasePositionFeeRateBPS: 5,
      initialMarginFractionBPS: 400,
      maintenanceMarginFractionBPS: 50,
      maxProfitRateBPS: 100000,
      assetClass: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("300000000", 30),
        maxFundingRate: ethers.utils.parseUnits("8", 18),
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 39,
      assetId: ethers.utils.formatBytes32String("AVAX"),
      maxLongPositionSize: ethers.utils.parseUnits("800000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("800000", 30),
      increasePositionFeeRateBPS: 5,
      decreasePositionFeeRateBPS: 5,
      initialMarginFractionBPS: 400,
      maintenanceMarginFractionBPS: 50,
      maxProfitRateBPS: 100000,
      assetClass: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30),
        maxFundingRate: ethers.utils.parseUnits("8", 18),
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 44,
      assetId: ethers.utils.formatBytes32String("1000PEPE"),
      maxLongPositionSize: ethers.utils.parseUnits("400000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("400000", 30),
      increasePositionFeeRateBPS: 5,
      decreasePositionFeeRateBPS: 5,
      initialMarginFractionBPS: 1000,
      maintenanceMarginFractionBPS: 50,
      maxProfitRateBPS: 40000,
      assetClass: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30),
        maxFundingRate: ethers.utils.parseUnits("8", 18),
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 45,
      assetId: ethers.utils.formatBytes32String("1000SHIB"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
      increasePositionFeeRateBPS: 5,
      decreasePositionFeeRateBPS: 5,
      initialMarginFractionBPS: 400,
      maintenanceMarginFractionBPS: 50,
      maxProfitRateBPS: 100000,
      assetClass: 0,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30),
        maxFundingRate: ethers.utils.parseUnits("8", 18),
      },
      isAdaptiveFeeEnabled: true,
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
