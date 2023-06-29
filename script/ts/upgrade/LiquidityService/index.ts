import { ethers, tenderly, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const Contract = await ethers.getContractFactory("LiquidityService", deployer);
  const TARGET_ADDRESS = config.services.liquidity;

  console.log(`> Preparing to upgrade LiquidityService`);
  const newImplementation = await upgrades.prepareUpgrade(TARGET_ADDRESS, Contract);
  console.log(`> Done`);

  console.log(`> New LiquidityService Implementation address: ${newImplementation}`);
  const upgradeTx = await upgrades.upgradeProxy(TARGET_ADDRESS, Contract);
  console.log(`> ⛓ Tx is submitted: ${upgradeTx.deployTransaction.hash}`);
  console.log(`> Waiting for tx to be mined...`);
  await upgradeTx.deployTransaction.wait(3);
  console.log(`> Tx is mined!`);

  console.log(`> Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "LiquidityService",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
