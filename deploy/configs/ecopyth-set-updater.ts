import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const updater = config.handlers.limitTrade;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);

  console.log("> EcoPyth Set Updater...");
  await (await ecoPyth.setUpdater(updater, true)).wait();
  console.log("> EcoPyth Set Updater success!");
};
export default func;
func.tags = ["EcoPythSetUpdater"];
