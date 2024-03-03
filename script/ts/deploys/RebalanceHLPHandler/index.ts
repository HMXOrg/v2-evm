import { ethers, upgrades, network, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("RebalanceHLPHandler", deployer);

  console.log(`[deploys/RebalanceHLPHandler] Deploying RebalanceHLPHandler Contract`);
  const contract = await upgrades.deployProxy(Contract, [config.services.rebalanceHLP, config.oracles.ecoPyth2]);
  await contract.deployed();
  console.log(`[deploys/RebalanceHLPHandler] Deployed at: ${contract.address}`);

  config.handlers.rebalanceHLP = contract.address;
  writeConfigFile(config);

  run("verify:verify", {
    address: await getImplementationAddress(network.provider, contract.address),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
