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
  assetId: ethers.utils.formatBytes32String("ETH"),
  increasePositionFeeRateBPS: 7, // 0.07%
  decreasePositionFeeRateBPS: 7, // 0.07%
  initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
  maintenanceMarginFractionBPS: 50, // MMF = 0.5%
  maxProfitRateBPS: 150000, // 1500%
  assetClass: cryptoAssetClass,
  allowIncreasePosition: true,
  active: true,
  fundingRate: {
    maxSkewScaleUSD: ethers.utils.parseUnits("1000000000", 30), // 1000 M
    maxFundingRate: ethers.utils.parseUnits("9", 18), // 900% per day
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
