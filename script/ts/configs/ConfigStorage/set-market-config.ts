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
      maxLongPositionSize: ethers.utils.parseUnits("5500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("6000000", 30),
      increasePositionFeeRateBPS: 4, // 0.04%
      decreasePositionFeeRateBPS: 4, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 250000, // 2500%
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
      maxLongPositionSize: ethers.utils.parseUnits("5500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("6000000", 30),
      increasePositionFeeRateBPS: 4, // 0.04%
      decreasePositionFeeRateBPS: 4, // 0.04%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 250000, // 2500%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("3000000000", 30), // 3000 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
    },
    // {
    //   marketIndex: 3,
    //   assetId: ethers.utils.formatBytes32String("JPY"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 4,
    //   assetId: ethers.utils.formatBytes32String("XAU"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 5, // 0.05%
    //   decreasePositionFeeRateBPS: 5, // 0.05%
    //   initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
    //   maintenanceMarginFractionBPS: 100, // MMF = 1%
    //   maxProfitRateBPS: 75000, // 750%
    //   assetClass: assetClasses.commodities,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 8,
    //   assetId: ethers.utils.formatBytes32String("EUR"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 9,
    //   assetId: ethers.utils.formatBytes32String("XAG"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 5, // 0.05%
    //   decreasePositionFeeRateBPS: 5, // 0.05%
    //   initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
    //   maintenanceMarginFractionBPS: 100, // MMF = 1%
    //   maxProfitRateBPS: 75000, // 750%
    //   assetClass: assetClasses.commodities,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 10,
    //   assetId: ethers.utils.formatBytes32String("AUD"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 11,
    //   assetId: ethers.utils.formatBytes32String("GBP"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 12,
    //   assetId: ethers.utils.formatBytes32String("ADA"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
    //   },
    // },
    // {
    //   marketIndex: 13,
    //   assetId: ethers.utils.formatBytes32String("MATIC"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
    //   },
    // },
    // {
    //   marketIndex: 14,
    //   assetId: ethers.utils.formatBytes32String("SUI"),
    //   maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 15,
    //   assetId: ethers.utils.formatBytes32String("ARB"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 16,
    //   assetId: ethers.utils.formatBytes32String("OP"),
    //   maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 17,
    //   assetId: ethers.utils.formatBytes32String("LTC"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 20,
    //   assetId: ethers.utils.formatBytes32String("BNB"),
    //   maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 21,
    //   assetId: ethers.utils.formatBytes32String("SOL"),
    //   maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 23,
    //   assetId: ethers.utils.formatBytes32String("XRP"),
    //   maxLongPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("1000000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("500000000", 30), // 500 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 25,
    //   assetId: ethers.utils.formatBytes32String("LINK"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("100000000", 30), // 100 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 26,
    //   assetId: ethers.utils.formatBytes32String("CHF"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 27,
    //   assetId: ethers.utils.formatBytes32String("DOGE"),
    //   maxLongPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("2500000", 30),
    //   increasePositionFeeRateBPS: 7, // 0.07%
    //   decreasePositionFeeRateBPS: 7, // 0.07%
    //   initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
    //   maintenanceMarginFractionBPS: 50, // MMF = 0.5%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.crypto,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("200000000", 30), // 200 M
    //     maxFundingRate: ethers.utils.parseUnits("8", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 28,
    //   assetId: ethers.utils.formatBytes32String("CAD"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 800% per day
    //   },
    // },
    // {
    //   marketIndex: 29,
    //   assetId: ethers.utils.formatBytes32String("SGD"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 30,
    //   assetId: ethers.utils.formatBytes32String("CNH"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 100% per day
    //   },
    // },
    // {
    //   marketIndex: 31,
    //   assetId: ethers.utils.formatBytes32String("HKD"),
    //   maxLongPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   maxShortPositionSize: ethers.utils.parseUnits("3000000", 30),
    //   increasePositionFeeRateBPS: 1, // 0.01%
    //   decreasePositionFeeRateBPS: 1, // 0.01%
    //   initialMarginFractionBPS: 10, // IMF = 0.1%, Max leverage = 1000
    //   maintenanceMarginFractionBPS: 5, // MMF = 0.05%
    //   maxProfitRateBPS: 250000, // 2500%
    //   assetClass: assetClasses.forex,
    //   allowIncreasePosition: true,
    //   active: true,
    //   fundingRate: {
    //     maxSkewScaleUSD: ethers.utils.parseUnits("10000000000", 30), // 10B
    //     maxFundingRate: ethers.utils.parseUnits("1", 18), // 800% per day
    //   },
    // },
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
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
