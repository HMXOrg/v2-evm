import { ethers, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const config = getConfig();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const VaultStorage = await ethers.getContractFactory("VaultStorage", deployer);
  const vaultStorageAddress = config.storages.vault;

  console.log(`[upgrade/VaultStorage] Preparing to upgrade VaultStorage`);
  const newImplementation = await upgrades.prepareUpgrade(vaultStorageAddress, VaultStorage);
  console.log(`[upgrade/VaultStorage] Done`);

  console.log(`[upgrade/VaultStorage] New VaultStorage Implementation address: ${newImplementation}`);
  console.log(`[upgrade/VaultStorage] Upgrading VaultStorage`);
  await proxyAdminWrapper.upgrade(vaultStorageAddress, newImplementation.toString());
  console.log(`[upgrade/VaultStorage] Done`);

  console.log(`[upgrade/VaultStorage] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "VaultStorage",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
