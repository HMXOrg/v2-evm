import { ethers, run, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const config = getConfig();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const LiquidationService = await ethers.getContractFactory("LiquidationService", deployer);
  const liquidationServiceAddress = config.services.liquidation;

  console.log(`[upgrade/LiquidationService] Preparing to upgrade LiquidationService`);
  const newImplementation = await upgrades.prepareUpgrade(liquidationServiceAddress, LiquidationService);
  console.log(`[upgrade/LiquidationService] Done`);

  console.log(`[upgrade/LiquidationService] New LiquidationService Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(liquidationServiceAddress, newImplementation.toString());
  console.log(`[upgrade/LiquidationService] Done`);

  console.log(`[upgrade/LiquidationService] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "LiquidationService",
  });

  console.log(`[upgrades/LiquidationService] Verify contract on Etherscan`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
