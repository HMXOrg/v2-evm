import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("PositionReader", deployer);
  const contract = await Contract.deploy(
    config.storages.config,
    config.storages.perp,
    config.oracles.middleware,
    config.calculator
  );
  await contract.deployed();
  console.log(`Deploying PositionReader Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.reader.position = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "PositionReader",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
