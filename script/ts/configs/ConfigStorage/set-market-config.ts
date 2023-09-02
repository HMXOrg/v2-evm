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
