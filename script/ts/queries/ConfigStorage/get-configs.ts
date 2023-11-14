import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { Calculator__factory, ConfigStorage__factory, PerpStorage__factory } from "../../../../typechain";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  console.log(ethers.utils.formatBytes32String("MEME"));
  console.log(ethers.utils.formatBytes32String("SEK"));
  console.log(ethers.utils.formatBytes32String("DIX"));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
