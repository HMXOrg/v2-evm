import { ethers, run, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LiquidationService", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.storages.perp,
    config.storages.vault,
    config.storages.config,
    config.helpers.trade,
  ]);
  await contract.deployed();
  console.log(`Deploying LiquidationService Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.services.liquidation = contract.address;
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
