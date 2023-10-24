import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("RebalanceHLPToGMXV2Handler", deployer);
  const contract = await upgrades.deployProxy(Contract, [config.services.rebalanceHLPToGMXV2]);
  await contract.deployed();

  console.log(`Deploying RebalanceHLPToGMXV2Handler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.rebalanceHLPToGMXV2 = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "RebalanceHLPToGMXV2Handler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
