import { ethers, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const config = getConfig();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const GasService = await ethers.getContractFactory("GasService", deployer);
  const gasServiceAddress = config.services.gas;

  console.log(`[upgrade/GasService] Preparing to upgrade GasService`);
  const newImplementation = await upgrades.prepareUpgrade(gasServiceAddress, GasService);
  console.log(`[upgrade/GasService] Done`);

  console.log(`[upgrade/GasService] New GasService Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(gasServiceAddress, newImplementation.toString());
  console.log(`[upgrade/GasService] Done`);

  console.log(`[upgrade/GasService] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "GasService",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
