import { ethers, run, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("MockChronicleOraclePriceAdapter", [], deployer);

  await contract.deployed();
  console.log(`[deploys/MockChronicleOraclePriceAdapter] Deploying MockChronicleOraclePriceAdapter Contract`);
  console.log(`[deploys/MockChronicleOraclePriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.wusdm = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
    constructorArguments: [],
  });
  await tenderly.verify({
    address: contract.address,
    name: "MockChronicleOraclePriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
