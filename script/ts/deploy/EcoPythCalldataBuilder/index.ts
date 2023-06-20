import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("EcoPythCalldataBuilder", deployer);
  const contract = await Contract.deploy(config.oracles.ecoPyth);
  await contract.deployed();
  console.log(`Deploying EcoPythCalldataBuilder Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.oracles.ecoPythCalldataBuilder = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "EcoPythCalldataBuilder",
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
