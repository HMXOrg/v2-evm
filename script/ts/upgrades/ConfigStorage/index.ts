import { ethers, run, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const config = getConfig();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const ConfigStorage = await ethers.getContractFactory("ConfigStorage", deployer);
  const configStorageAddress = config.storages.config;

  console.log(`[upgrade/ConfigStorage] Preparing to upgrade ConfigStorage`);
  const newImplementation = await upgrades.prepareUpgrade(configStorageAddress, ConfigStorage);
  console.log(`[upgrade/ConfigStorage] Done`);

  console.log(`[upgrade/ConfigStorage] New ConfigStorage Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(configStorageAddress, newImplementation.toString());
  console.log(`[upgrade/ConfigStorage] Done`);

  console.log(`[upgrade/ConfigStorage] Verify contract`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
