import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Add Asset Class Config...");
  await (
    await configStorage.addAssetClassConfig({
      baseBorrowingRate: ethers.utils.parseEther("0.00000003"), // 0.01% per hour
    })
  ).wait();
  console.log("> ConfigStorage: Add Asset Class Config success!");
};
export default func;
func.tags = ["AddAssetClassConfigCommodities"];
