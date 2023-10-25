import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { Calculator__factory, ConfigStorage__factory, PerpStorage__factory } from "../../../../typechain";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  await (await configStorage.removeHlpAssetId(8)).wait();
  console.log(await configStorage.getHlpAssetIds());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
