import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying EcoPythCalldataBuilder2 Contract`);
  const Contract = await ethers.getContractFactory("EcoPythCalldataBuilder2", deployer);
  const contract = await Contract.deploy(config.oracles.ecoPyth2, config.oracles.onChainPriceLens, true);
  await contract.deployed();
  console.log(`Deployed at: ${contract.address}`);

  config.oracles.ecoPythCalldataBuilder2 = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "EcoPythCalldataBuilder2",
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
