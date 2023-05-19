import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage setTradeServiceHooks...");
  await (await configStorage.setTradeServiceHooks([config.hooks.tlc, config.hooks.tradingStaking])).wait();
  console.log("> ConfigStorage setTradeServiceHooks success!");
};
export default func;
func.tags = ["SetTradeServiceHooks"];
