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
      marketIndex: 16,
      assetId: ethers.utils.formatBytes32String("OP"),
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 400000, // 4000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
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
