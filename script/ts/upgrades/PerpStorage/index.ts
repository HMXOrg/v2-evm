import { ethers, run, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const chainId = await deployer.getChainId();

  const proxyWrapper = new ProxyAdminWrapper(chainId, deployer);
  const Contract = await ethers.getContractFactory("PerpStorage", deployer);
  const TARGET_ADDRESS = config.storages.perp;

  console.log(`[upgrades/PerpStorage] Preparing to upgrade PerpStorage`);
  const newImplementation = await upgrades.prepareUpgrade(TARGET_ADDRESS, Contract);
  console.log(`[upgrades/PerpStorage] Done`);

  console.log(`[upgrades/PerpStorage] New PerpStorage Implementation address: ${newImplementation}`);
  await proxyWrapper.upgrade(TARGET_ADDRESS, newImplementation.toString());
  console.log(`[upgrades/PerpStorage] Tx is mined!`);

  console.log(`[upgrades/PerpStorage] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "PerpStorage",
  });

  console.log(`[upgrades/PerpStorage] Verify contract on Etherscan`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
