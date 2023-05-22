import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Trading Config...");
  await (
    await configStorage.setTradingConfig({
      fundingInterval: 1, // second
      devFeeRateBPS: 1500, // 15%
      minProfitDuration: 15, // second
      maxPosition: 10,
    })
  ).wait();
  console.log("> ConfigStorage: Set Trading Config success!");
};
export default func;
func.tags = ["SetTradingConfig"];
