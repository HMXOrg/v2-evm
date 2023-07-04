import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying MockBalancerVault Contract`);
  const Contract = await ethers.getContractFactory("MockBalancerVault", deployer);
  const contract = await Contract.deploy();
  await contract.deployed();
  console.log(`Deployed at: ${contract.address}`);

  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "MockBalancerVault",
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
