import { ethers, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const config = getConfig();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const IntentHandler = await ethers.getContractFactory("IntentHandler", deployer);
  const intentHandlerAddress = config.handlers.intent;

  console.log(`[upgrade/IntentHandler] Preparing to upgrade IntentHandler`);
  const newImplementation = await upgrades.prepareUpgrade(intentHandlerAddress, IntentHandler);
  console.log(`[upgrade/IntentHandler] Done`);

  console.log(`[upgrade/IntentHandler] New IntentHandler Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(intentHandlerAddress, newImplementation.toString());
  console.log(`[upgrade/IntentHandler] Done`);

  console.log(`[upgrade/IntentHandler] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "IntentHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
