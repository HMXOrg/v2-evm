import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network, getChainId } from "hardhat";
import { getConfig, loadConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const LiquidationService = await ethers.getContractFactory("LiquidationService", deployer);
  const liquidationService = config.services.liquidation;

  console.log(`[upgrade/LiquidationService] Preparing to upgrade LiquidationService`);
  const newImplementation = await upgrades.prepareUpgrade(liquidationService, LiquidationService);
  console.log(`[upgrade/LiquidationService] Done`);

  console.log(`[upgrade/LiquidationService] New LiquidationService Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(liquidationService, newImplementation.toString());
  console.log(`[upgrade/LiquidationService] Upgraded!`);

  console.log(`[upgrade/LiquidationService] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "LiquidationService",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
