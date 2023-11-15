import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying LimitTradeOrderBuilder Contract`);
  const Contract = await ethers.getContractFactory("LimitTradeOrderBuilder", deployer);
  const contract = await Contract.deploy(config.storages.config);
  await contract.deployed();
  console.log(`Deployed at: ${contract.address}`);

  config.helpers.limitTradeOrderBuilder = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "LimitTradeOrderBuilder",
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
