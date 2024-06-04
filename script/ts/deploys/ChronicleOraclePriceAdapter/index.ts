import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

const chroniclePriceFeedAddress = "";

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("ChronicleOraclePriceAdapter", [chroniclePriceFeedAddress], deployer);

  await contract.deployed();
  console.log(`[deploys/ChronicleOraclePriceAdapter] Deploying ChronicleOraclePriceAdapter Contract`);
  console.log(`[deploys/ChronicleOraclePriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.wusdm = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
    constructorArguments: [chroniclePriceFeedAddress],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
