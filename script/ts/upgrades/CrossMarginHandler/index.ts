import { ethers, run, upgrades } from "hardhat";
import { loadConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const config = loadConfig(chainId);

  const TARGET_ADDRESS = config.handlers.crossMargin;
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const Contract = await ethers.getContractFactory("CrossMarginHandler", deployer);

  console.log(`[upgrade/CrossMarginHandler] Preparing to upgrade CrossMarginHandler`);
  const newImplementation = await upgrades.prepareUpgrade(TARGET_ADDRESS, Contract);
  console.log(`[upgrade/CrossMarginHandler] Done`);

  console.log(`[upgrade/CrossMarginHandler] New CrossMarginHandler Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(TARGET_ADDRESS, newImplementation.toString());

  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
