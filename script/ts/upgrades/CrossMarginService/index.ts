import { ethers, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const Contract = await ethers.getContractFactory("CrossMarginService", deployer);
  const TARGET_ADDRESS = config.services.crossMargin;

  console.log(`[upgrade/CrossMarginService] Preparing to upgrade CrossMarginService`);
  const newImplementation = await upgrades.prepareUpgrade(TARGET_ADDRESS, Contract);
  console.log(`[upgrade/CrossMarginService] Done`);
  console.log(`[upgrade/CrossMarginService] New CrossMarginService Implementation address: ${newImplementation}`);

  await proxyAdminWrapper.upgrade(TARGET_ADDRESS, newImplementation.toString());

  console.log(`[upgrade/CrossMarginService] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "CrossMarginService",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
