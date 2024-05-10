import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("TokenSettingHelper", deployer);

  const contract = await upgrades.deployProxy(Contract, [config.storages.vault, config.storages.config]);

  await contract.deployed();
  console.log(`[deploys/TokenSettingHelper] Deploying TokenSettingHelper Contract`);
  console.log(`[deploys/TokenSettingHelper] Deployed at: ${contract.address}`);

  config.helpers.tokenSetting = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "TokenSettingHelper",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
