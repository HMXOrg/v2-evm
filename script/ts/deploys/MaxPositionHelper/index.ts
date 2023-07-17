import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying MaxPositionHelper Contract`);
  const Contract = await ethers.getContractFactory("MaxPositionHelper", deployer);
  const contract = await Contract.deploy(config.storages.config, config.storages.perp);
  await contract.deployed();
  console.log(`Deployed at: ${contract.address}`);

  config.helpers.maxPositionHelper = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "MaxPositionHelper",
  });
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
