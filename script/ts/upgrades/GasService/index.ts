import { ethers, run, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const GasService = await ethers.getContractFactory("GasService", deployer);
  const gasService = config.services.gas;

  console.log(`[upgrade/GasService] Preparing to upgrade GasService`);
  const newImplementation = await upgrades.prepareUpgrade(gasService, GasService);
  console.log(`[upgrade/GasService] Done`);

  console.log(`[upgrade/GasService] New GasService Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(gasService, newImplementation.toString());
  console.log(`[upgrade/GasService] Upgraded!`);

  console.log(`[upgrade/GasService] Verify contract`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
