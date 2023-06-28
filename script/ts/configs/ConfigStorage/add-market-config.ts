import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import assetClasses from "../../entities/asset-classes";

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

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const marketConfigs: Array<AddMarketConfig> = [
    {
      assetId: ethers.utils.formatBytes32String("AUD"),
      increasePositionFeeRateBPS: 1, // 0.01%
      decreasePositionFeeRateBPS: 1, // 0.01%
      initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
      maintenanceMarginFractionBPS: 5, // MMF = 0.05%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.forex,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1b
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 10% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
    },
    {
      assetId: ethers.utils.formatBytes32String("GBP"),
      increasePositionFeeRateBPS: 1, // 0.01%
      decreasePositionFeeRateBPS: 1, // 0.01%
      initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
      maintenanceMarginFractionBPS: 5, // MMF = 0.05%
      maxProfitRateBPS: 200000, // 2000%
      assetClass: assetClasses.forex,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1b
        maxFundingRate: ethers.utils.parseUnits("1", 18), // 10% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
    },
    {
      assetId: ethers.utils.formatBytes32String("ADA"),
      increasePositionFeeRateBPS: 7, // 0.04%
      decreasePositionFeeRateBPS: 7, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1b
        maxFundingRate: ethers.utils.parseUnits("9", 18), // 900% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
    },
    {
      assetId: ethers.utils.formatBytes32String("MATIC"),
      increasePositionFeeRateBPS: 7, // 0.04%
      decreasePositionFeeRateBPS: 7, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1b
        maxFundingRate: ethers.utils.parseUnits("9", 18), // 900% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
    },
    {
      assetId: ethers.utils.formatBytes32String("SUI"),
      increasePositionFeeRateBPS: 7, // 0.04%
      decreasePositionFeeRateBPS: 7, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 150000, // 1500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("250000000", 30), // 250 M
        maxFundingRate: ethers.utils.parseUnits("9", 18), // 900% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    },
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[ConfigStorage] Adding new market config...");
  for (let i = 0; i < marketConfigs.length; i++) {
    console.log(`[ConfigStorage] Adding ${ethers.utils.parseBytes32String(marketConfigs[i].assetId)} market config...`);
    const tx = await configStorage.addMarketConfig(marketConfigs[i]);
    console.log(`[ConfigStorage] Tx: ${tx.hash}`);
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
