import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const cryptoAssetClass = 0;
const equityAssetClass = 1;
const forexAssetClass = 2;
const commoditiesAssetClass = 3;

const marketConfig = {
  assetId: ethers.utils.formatBytes32String("XAG"),
  increasePositionFeeRateBPS: 5, // 0.05%
  decreasePositionFeeRateBPS: 5, // 0.05%
  initialMarginFractionBPS: 200, // IMF = 2%, Max leverage = 50
  maintenanceMarginFractionBPS: 100, // MMF = 1%
  maxProfitRateBPS: 75000, // 750%
  assetClass: commoditiesAssetClass,
  allowIncreasePosition: true,
  active: true,
  fundingRate: {
    maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 300 M
    maxFundingRate: ethers.utils.parseUnits("1", 18), // 10% per day
  },
  maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
  maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
};

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Add Market Config...");
  await (await configStorage.addMarketConfig(marketConfig)).wait();
  console.log("> ConfigStorage: Add Market Config success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
