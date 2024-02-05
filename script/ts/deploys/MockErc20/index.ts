import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const constructorArguments = [
    "USDT", // name
    "USDT", // symbol
    6, // decimals
  ];
  const contract = await ethers.deployContract("MockErc20", constructorArguments, deployer);

  await contract.deployed();
  console.log(`[deploys/MockErc20] Deploying MockErc20 Contract`);
  console.log(`[deploys/MockErc20] Deployed at: ${contract.address}`);

  config.tokens.usdt = contract.address;
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
