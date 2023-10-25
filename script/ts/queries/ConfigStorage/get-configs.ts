import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { Calculator__factory, ConfigStorage__factory, PerpStorage__factory } from "../../../../typechain";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  console.log(
    "glp",
    await configStorage.assetHlpTokenConfigs("0x474c500000000000000000000000000000000000000000000000000000000000")
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
