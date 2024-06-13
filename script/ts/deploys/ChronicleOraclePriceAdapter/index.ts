import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const chroniclePriceFeedAddress = "0xdC6720c996Fad27256c7fd6E0a271e2A4687eF18";

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
