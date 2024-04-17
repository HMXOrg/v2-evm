import { ethers, run, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("TradeHelper", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.storages.perp,
    config.storages.vault,
    config.storages.config,
  ]);
  await contract.deployed();
  console.log(`Deploying TradeHelper Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.helpers.trade = contract.address;
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
