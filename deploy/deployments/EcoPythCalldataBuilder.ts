import { ethers } from "hardhat";
import { getConfig } from "../utils/config";

async function main() {
  const config = getConfig();
  const ECO_PYTH_ADDRESS = config.oracles.ecoPyth;

  console.log(`Deploying EcoPythCalldataBuilder`);
  const deployer = (await ethers.getSigners())[0];
  const EcoPythCalldataBuilder = await ethers.getContractFactory("EcoPythCalldataBuilder", deployer);
  const ecoPythCalldataBuilder = await EcoPythCalldataBuilder.deploy(ECO_PYTH_ADDRESS);
  console.log("Waiting for EcoPythCalldataBuilder to be deployed...");
  await ecoPythCalldataBuilder.deployTransaction.wait(1);
  console.log(`Deployed at: ${ecoPythCalldataBuilder.address}`);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
