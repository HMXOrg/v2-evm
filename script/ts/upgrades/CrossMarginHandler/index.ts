import { ethers, run, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("CrossMarginHandler", deployer);
  const TARGET_ADDRESS = config.handlers.crossMargin;

  console.log(`[upgrade/CrossMarginHandler] Preparing to upgrade CrossMarginHandler`);
  const newImplementation = await upgrades.prepareUpgrade(TARGET_ADDRESS, Contract);
  console.log(`[upgrade/CrossMarginHandler] Done`);

  console.log(`[upgrade/CrossMarginHandler] New CrossMarginHandler Implementation address: ${newImplementation}`);
  const upgradeTx = await upgrades.upgradeProxy(TARGET_ADDRESS, Contract);
  console.log(`[upgrade/CrossMarginHandler] ⛓ Tx is submitted: ${upgradeTx.deployTransaction.hash}`);
  console.log(`[upgrade/CrossMarginHandler] Waiting for tx to be mined...`);
  await upgradeTx.deployTransaction.wait(3);
  console.log(`[upgrade/CrossMarginHandler] Tx is mined!`);

  console.log(`[upgrade/CrossMarginHandler] Verify contract`);

  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
