import { ethers, run, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("PythAdapter", deployer);
  const contract = await upgrades.deployProxy(Contract, [config.oracles.ecoPyth2]);
  await contract.deployed();
  console.log(`Deploying PythAdapter Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.oracles.pythAdapter = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: await getImplementationAddress(network.provider, contract.address),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
