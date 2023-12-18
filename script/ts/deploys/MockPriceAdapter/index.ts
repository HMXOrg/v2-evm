import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const initialPrice = ethers.utils.parseEther("0.8");
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("MockPriceAdapter", [initialPrice], deployer);

  await contract.deployed();
  console.log(`[deploys/MockPriceAdapter] Deploying MockPriceAdapter Contract`);
  console.log(`[deploys/MockPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.glp = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "MockPriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
