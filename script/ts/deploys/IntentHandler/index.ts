import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("IntentHandler", deployer);

  const contract = await upgrades.deployProxy(Contract, [
    config.oracles.ecoPyth2,
    config.storages.config,
    config.helpers.tradeOrder,
    config.services.gas,
  ]);
  await contract.deployed();
  console.log(`Deploying IntentHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.intent = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "IntentHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
