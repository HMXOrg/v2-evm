import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("IntentBuilder", [], deployer);

  await contract.deployed();
  console.log(`[deploys/Dexter] Deploying IntentBuilder Contract`);
  console.log(`[deploys/Dexter] Deployed at: ${contract.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
