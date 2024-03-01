import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const constructorArguments = [config.tokens.usdt!];
  const contract = await ethers.deployContract("TestTokenMinter", constructorArguments, deployer);

  await contract.deployed();
  console.log(`[deploys/TestTokenMinter] Deploying TestTokenMinter Contract`);
  console.log(`[deploys/TestTokenMinter] Deployed at: ${contract.address}`);

  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
    constructorArguments,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
