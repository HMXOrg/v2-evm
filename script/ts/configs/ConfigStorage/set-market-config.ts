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
      marketIndex: 35,
      assetId: ethers.utils.formatBytes32String("JTO"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 42,
      assetId: ethers.utils.formatBytes32String("SEI"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 41,
      assetId: ethers.utils.formatBytes32String("DOT"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 32,
      assetId: ethers.utils.formatBytes32String("BCH"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("300000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 17,
      assetId: ethers.utils.formatBytes32String("LTC"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 12,
      assetId: ethers.utils.formatBytes32String("ADA"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("300000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 47,
      assetId: ethers.utils.formatBytes32String("ICP"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 43,
      assetId: ethers.utils.formatBytes32String("ATOM"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 13,
      assetId: ethers.utils.formatBytes32String("MATIC"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("300000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 48,
      assetId: ethers.utils.formatBytes32String("MANTA"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: false,
    },
    {
      marketIndex: 40,
      assetId: ethers.utils.formatBytes32String("INJ"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 38,
      assetId: ethers.utils.formatBytes32String("TIA"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 14,
      assetId: ethers.utils.formatBytes32String("SUI"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 36,
      assetId: ethers.utils.formatBytes32String("STX"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 33,
      assetId: ethers.utils.formatBytes32String("MEME"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("300000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 37,
      assetId: ethers.utils.formatBytes32String("ORDI"),
      maxLongPositionSize: BigNumber.from(0),
      maxShortPositionSize: BigNumber.from(0),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
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
    // await safeWrapper.proposeTransaction(
    //   tradeHelper.address,
    //   0,
    //   tradeHelper.interface.encodeFunctionData("updateBorrowingRate", [marketConfigs[i].assetClass])
    // );
    // await safeWrapper.proposeTransaction(
    //   tradeHelper.address,
    //   0,
    //   tradeHelper.interface.encodeFunctionData("updateFundingRate", [marketConfigs[i].marketIndex])
    // );
    const tx = await safeWrapper.proposeTransaction(
      configStorage.address,
      0,
      configStorage.interface.encodeFunctionData("setMarketConfig", [
        marketConfigs[i].marketIndex,
        marketConfigs[i],
        marketConfigs[i].isAdaptiveFeeEnabled,
      ])
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
