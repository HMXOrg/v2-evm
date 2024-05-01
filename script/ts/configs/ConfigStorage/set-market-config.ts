import { ethers } from "ethers";
import { ConfigStorage__factory, TradeHelper__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import assetClasses from "../../entities/asset-classes";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

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
      marketIndex: 8,
      assetId: ethers.utils.formatBytes32String("ADA"),
      maxLongPositionSize: ethers.utils.parseUnits("500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("500000", 30),
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
      marketIndex: 9,
      assetId: ethers.utils.formatBytes32String("MATIC"),
      maxLongPositionSize: ethers.utils.parseUnits("500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("500000", 30),
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
      marketIndex: 10,
      assetId: ethers.utils.formatBytes32String("SUI"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 11,
      assetId: ethers.utils.formatBytes32String("ARB"),
      maxLongPositionSize: ethers.utils.parseUnits("500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("500000", 30),
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
      assetId: ethers.utils.formatBytes32String("OP"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 13,
      assetId: ethers.utils.formatBytes32String("LTC"),
      maxLongPositionSize: ethers.utils.parseUnits("500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("500000", 30),
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
      marketIndex: 14,
      assetId: ethers.utils.formatBytes32String("BNB"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 15,
      assetId: ethers.utils.formatBytes32String("SOL"),
      maxLongPositionSize: ethers.utils.parseUnits("300000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("300000", 30),
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
      marketIndex: 16,
      assetId: ethers.utils.formatBytes32String("XRP"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 400, // IMF = 4%, Max leverage = 25
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 100000, // 1000%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("500000000", 30), // 500 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 17,
      assetId: ethers.utils.formatBytes32String("LINK"),
      maxLongPositionSize: ethers.utils.parseUnits("500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("500000", 30),
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
      marketIndex: 19,
      assetId: ethers.utils.formatBytes32String("DOGE"),
      maxLongPositionSize: ethers.utils.parseUnits("500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("500000", 30),
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
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 100% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 24,
      assetId: ethers.utils.formatBytes32String("BCH"),
      maxLongPositionSize: ethers.utils.parseUnits("500000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("500000", 30),
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
      marketIndex: 25,
      assetId: ethers.utils.formatBytes32String("MEME"),
      maxLongPositionSize: ethers.utils.parseUnits("400000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("400000", 30),
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
      marketIndex: 27,
      assetId: ethers.utils.formatBytes32String("JTO"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 28,
      assetId: ethers.utils.formatBytes32String("STX"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 29,
      assetId: ethers.utils.formatBytes32String("ORDI"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 30,
      assetId: ethers.utils.formatBytes32String("TIA"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 31,
      assetId: ethers.utils.formatBytes32String("AVAX"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      assetId: ethers.utils.formatBytes32String("INJ"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 33,
      assetId: ethers.utils.formatBytes32String("DOT"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 34,
      assetId: ethers.utils.formatBytes32String("SEI"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 35,
      assetId: ethers.utils.formatBytes32String("ATOM"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 36,
      assetId: ethers.utils.formatBytes32String("1000PEPE"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 37,
      assetId: ethers.utils.formatBytes32String("1000SHIB"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 39,
      assetId: ethers.utils.formatBytes32String("ICP"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 40,
      assetId: ethers.utils.formatBytes32String("MANTA"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      assetId: ethers.utils.formatBytes32String("STRK"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("50000000", 30), // 50 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 42,
      assetId: ethers.utils.formatBytes32String("PYTH"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("50000000", 30), // 50 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 900% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 43,
      assetId: ethers.utils.formatBytes32String("PENDLE"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
      increasePositionFeeRateBPS: 5, // 0.05%
      decreasePositionFeeRateBPS: 5, // 0.05%
      initialMarginFractionBPS: 1000, // IMF = 10%, Max leverage = 10
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 40000, // 400%
      assetClass: assetClasses.crypto,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("50000000", 30), // 50 M
        maxFundingRate: ethers.utils.parseUnits("8", 18), // 800% per day
      },
      isAdaptiveFeeEnabled: true,
    },
    {
      marketIndex: 44,
      assetId: ethers.utils.formatBytes32String("W"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
      marketIndex: 45,
      assetId: ethers.utils.formatBytes32String("ENA"),
      maxLongPositionSize: ethers.utils.parseUnits("200000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("200000", 30),
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
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const tradeHelper = TradeHelper__factory.connect(config.helpers.trade, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

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
    await ownerWrapper.authExec(
      configStorage.address,
      configStorage.interface.encodeFunctionData("setMarketConfig", [
        marketConfigs[i].marketIndex,
        marketConfigs[i],
        marketConfigs[i].isAdaptiveFeeEnabled,
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
