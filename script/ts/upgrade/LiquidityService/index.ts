import { ethers, tenderly, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const LiquidityService = await ethers.getContractFactory("LiquidityService", deployer);
  const liquidityService = config.services.liquidity;

  console.log(`[upgrade/LiquidityService] Preparing to upgrade LiquidityService`);
  const newImplementation = await upgrades.prepareUpgrade(liquidityService, LiquidityService);
  console.log(`[upgrade/LiquidityService] Done`);

  console.log(`[upgrade/LiquidityService] New LiquidityService Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(liquidityService, newImplementation.toString());
  console.log(`[upgrade/LiquidityService] Upgraded!`);

  console.log(`[upgrade/LiquidityService] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "LiquidityService",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
