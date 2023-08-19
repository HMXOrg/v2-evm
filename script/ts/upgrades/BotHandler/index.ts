import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network, getChainId } from "hardhat";
import { getConfig, loadConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const BotHandler = await ethers.getContractFactory("BotHandler", deployer);
  const botHandler = config.handlers.bot;

  console.log(`[upgrade/BotHandler] Preparing to upgrade BotHandler`);
  const newImplementation = await upgrades.prepareUpgrade(botHandler, BotHandler);
  console.log(`[upgrade/BotHandler] Done`);

  console.log(`[upgrade/BotHandler] New BotHandler Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(botHandler, newImplementation.toString());
  console.log(`[upgrade/BotHandler] Upgraded!`);

  console.log(`[upgrade/BotHandler] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "BotHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
