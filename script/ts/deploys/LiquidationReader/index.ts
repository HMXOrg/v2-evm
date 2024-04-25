import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LiquidationReader", deployer);
  const contract = await Contract.deploy(config.storages.perp, config.calculator);

  await contract.deployed();
  console.log(`Deploying LiquidationReader Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.reader.liquidation = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "LiquidationReader",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
