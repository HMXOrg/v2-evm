import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("CIXPriceAdapter", [], deployer);

  await contract.deployed();
  console.log(`[deploys/CIXPriceAdapter] Deploying CIXPriceAdapter Contract`);
  console.log(`[deploys/CIXPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.dix = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "CIXPriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
