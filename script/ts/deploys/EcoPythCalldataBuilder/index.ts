import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying EcoPythCalldataBuilder Contract`);
  const Contract = await ethers.getContractFactory("EcoPythCalldataBuilder", deployer);
  const contract = await Contract.deploy(config.oracles.ecoPyth2, config.vendors.gmx.glpManager, config.tokens.sglp);
  await contract.deployed();
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
