import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("MockGmPriceAdapter", [ethers.utils.parseEther("1.1")], deployer);

  await contract.deployed();
  console.log(`[deploys/GmPriceAdapter] Deploying GmPriceAdapter for GM-BTCUSD Contract`);
  console.log(`[deploys/GmPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.gmETHUSD = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "MockGmPriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
