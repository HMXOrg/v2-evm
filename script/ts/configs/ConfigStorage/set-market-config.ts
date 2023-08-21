import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
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
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const marketConfigs: Array<AddMarketConfig> = [
    {
      marketIndex: 1,
      assetId: ethers.utils.formatBytes32String("BTC"),
      increasePositionFeeRateBPS: 4, // 0.04%
      decreasePositionFeeRateBPS: 4, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("3000000000", 30), // 3000 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("5000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("5000000", 30),
    },
    {
      marketIndex: 14,
      assetId: ethers.utils.formatBytes32String("SUI"),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 15,
      assetId: ethers.utils.formatBytes32String("ARB"),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    },
    {
      marketIndex: 16,
      assetId: ethers.utils.formatBytes32String("OP"),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 17,
      assetId: ethers.utils.formatBytes32String("LTC"),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    },
    {
      marketIndex: 20,
      assetId: ethers.utils.formatBytes32String("BNB"),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 21,
      assetId: ethers.utils.formatBytes32String("SOL"),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 25,
      assetId: ethers.utils.formatBytes32String("LINK"),
      increasePositionFeeRateBPS: 7, // 0.07%
      decreasePositionFeeRateBPS: 7, // 0.07%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    },
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const safeWrapper = new SafeWrapper(chainId, deployer);

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
    const tx = await safeWrapper.proposeTransaction(
      configStorage.address,
      0,
      configStorage.interface.encodeFunctionData("setMarketConfig", [marketConfigs[i].marketIndex, marketConfigs[i]])
    );
    console.log(`[ConfigStorage] Tx: ${tx}`);
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
