import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage setTradeServiceHooks...");
  await (await configStorage.setTradeServiceHooks([config.hooks.tlc, config.hooks.tradingStaking])).wait();
  console.log("> ConfigStorage setTradeServiceHooks success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
