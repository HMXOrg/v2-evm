import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const assetClassName = "COMMODITY";
const assetConfig = {
  baseBorrowingRate: ethers.utils.parseEther("0.000000000002536783"), // 0.008% per hour
};

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log(`> ConfigStorage: Add ${assetClassName} Asset Class Config...`);
  await (await configStorage.addAssetClassConfig(assetConfig)).wait();
  console.log(`> ConfigStorage: Add ${assetClassName} Asset Class Config success!`);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
