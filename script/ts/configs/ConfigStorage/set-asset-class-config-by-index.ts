import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const cryptoAssetClass = 0;
const equityAssetClass = 1;
const forexAssetClass = 2;
const commoditiesAssetClass = 3;

const assetIndex = commoditiesAssetClass;
const assetConfig = {
  baseBorrowingRate: ethers.utils.parseEther("0.000000022222222222"), // 0.008% per hour
};

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Asset Class Config By Index...");
  await (await configStorage.setAssetClassConfigByIndex(assetIndex, assetConfig)).wait();
  console.log("> ConfigStorage: Set Asset Class Config By Index success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
