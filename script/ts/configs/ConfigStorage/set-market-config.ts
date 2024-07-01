import { ethers } from "ethers";
import { ConfigStorage__factory, IConfigStorage__factory, TradeHelper__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import assetClasses from "../../entities/asset-classes";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import * as readlineSync from "readline-sync";

type UnstrictedMarketConfig = {
  marketIndex: number;
  increasePositionFeeRateBPS?: number | undefined;
  decreasePositionFeeRateBPS?: number | undefined;
  initialMarginFractionBPS?: number | undefined;
  maintenanceMarginFractionBPS?: number | undefined;
  maxProfitRateBPS?: number | undefined;
  allowIncreasePosition?: boolean | undefined;
  active?: boolean | undefined;
  fundingRate?: {
    maxSkewScaleUSD?: ethers.BigNumber | undefined;
    maxFundingRate?: ethers.BigNumber | undefined;
  };
  maxLongPositionSize?: ethers.BigNumber | undefined;
  maxShortPositionSize?: ethers.BigNumber | undefined;
  isAdaptiveFeeEnabled?: boolean | undefined;
};

type StrictedMarketConfig = {
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

  const inputMarketConfigs: Array<UnstrictedMarketConfig> = [
    {
      marketIndex: 3,
      allowIncreasePosition: true,
    },
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const currentMarketConfigs = await configStorage.getMarketConfigs();

  const toBeMarketConfigs = await Promise.all(
    inputMarketConfigs.map(async (each) => {
      return {
        ...currentMarketConfigs[each.marketIndex],
        isAdaptiveFeeEnabled: await configStorage.isAdaptiveFeeEnabledByMarketIndex(each.marketIndex),
        ...each,
      } as StrictedMarketConfig;
    })
  );
  console.log("Press Option+Z for the console text to overflow");
  for (let i = 0; i < toBeMarketConfigs.length; i++) {
    const each = toBeMarketConfigs[i];
    const existingMarketConfig = currentMarketConfigs[each.marketIndex];
    const existing = {
      marketIndex: each.marketIndex,
      assetId: ethers.utils.parseBytes32String(existingMarketConfig.assetId),
      increasePositionFeeRateBPS: existingMarketConfig.increasePositionFeeRateBPS,
      decreasePositionFeeRateBPS: existingMarketConfig.decreasePositionFeeRateBPS,
      initialMarginFractionBPS: existingMarketConfig.initialMarginFractionBPS,
      maintenanceMarginFractionBPS: existingMarketConfig.maintenanceMarginFractionBPS,
      maxProfitRateBPS: existingMarketConfig.maxProfitRateBPS,
      assetClass: existingMarketConfig.assetClass,
      allowIncreasePosition: existingMarketConfig.allowIncreasePosition,
      active: existingMarketConfig.active,
      fundingRate: {
        maxSkewScaleUSD: existingMarketConfig.fundingRate.maxSkewScaleUSD.toString(),
        maxFundingRate: existingMarketConfig.fundingRate.maxFundingRate.toString(),
      },
      maxLongPositionSize: existingMarketConfig.maxLongPositionSize.toString(),
      maxShortPositionSize: existingMarketConfig.maxShortPositionSize.toString(),
      isAdaptiveFeeEnabled: await configStorage.isAdaptiveFeeEnabledByMarketIndex(each.marketIndex),
    };
    const newOne = {
      marketIndex: each.marketIndex,
      assetId: ethers.utils.parseBytes32String(each.assetId),
      increasePositionFeeRateBPS: each.increasePositionFeeRateBPS,
      decreasePositionFeeRateBPS: each.decreasePositionFeeRateBPS,
      initialMarginFractionBPS: each.initialMarginFractionBPS,
      maintenanceMarginFractionBPS: each.maintenanceMarginFractionBPS,
      maxProfitRateBPS: each.maxProfitRateBPS,
      assetClass: each.assetClass,
      allowIncreasePosition: each.allowIncreasePosition,
      active: each.active,
      fundingRate: {
        maxSkewScaleUSD: each.fundingRate.maxSkewScaleUSD?.toString(),
        maxFundingRate: each.fundingRate.maxFundingRate?.toString(),
      },
      maxLongPositionSize: each.maxLongPositionSize.toString(),
      maxShortPositionSize: each.maxShortPositionSize.toString(),
      isAdaptiveFeeEnabled: each.isAdaptiveFeeEnabled,
    };
    console.table({ existing, newOne });
    const confirm = readlineSync.question(
      `[configs/ConfigStorage] Confirm to update market index ${each.marketIndex}? (y/n): `
    );
    switch (confirm) {
      case "y":
        break;
      case "n":
        console.log("[configs/ConfigStorage] Set Market Config cancelled!");
        return;
      default:
        console.log("[configs/ConfigStorage] Invalid input!");
        return;
    }
  }

  console.log("[ConfigStorage] Setting market config...");
  for (let i = 0; i < toBeMarketConfigs.length; i++) {
    console.log(
      `[ConfigStorage] Setting ${ethers.utils.parseBytes32String(toBeMarketConfigs[i].assetId)} market config...`
    );
    const existingMarketConfig = currentMarketConfigs[toBeMarketConfigs[i].marketIndex];
    if (existingMarketConfig.assetId !== toBeMarketConfigs[i].assetId) {
      console.log(`marketIndex ${toBeMarketConfigs[i].marketIndex} wrong asset id`);
      throw "bad asset id";
    }
    await ownerWrapper.authExec(
      configStorage.address,
      configStorage.interface.encodeFunctionData("setMarketConfig", [
        toBeMarketConfigs[i].marketIndex!,
        toBeMarketConfigs[i],
        toBeMarketConfigs[i].isAdaptiveFeeEnabled!,
      ])
    );
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
