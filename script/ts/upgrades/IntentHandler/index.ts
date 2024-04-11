import { ethers, run, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const IntentHandler = await ethers.getContractFactory("IntentHandler", deployer);
  const intentHandler = config.handlers.intent;

  console.log(`[upgrade/IntentHandler] Preparing to upgrade IntentHandler`);
  const newImplementation = await upgrades.prepareUpgrade(intentHandler, IntentHandler);
  console.log(`[upgrade/IntentHandler] Done`);

  console.log(`[upgrade/IntentHandler] New IntentHandler Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(intentHandler, newImplementation.toString());
  console.log(`[upgrade/IntentHandler] Upgraded!`);

  console.log(`[upgrade/IntentHandler] Verify contract`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
