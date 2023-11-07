import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();
const minHLPValueLossBPS = 50; // 0.5%

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("RebalanceHLPv2Service", deployer);

  const contract = await upgrades.deployProxy(Contract, [
    config.storages.vault,
    config.storages.config,
    config.vendors.gmxV2.exchangeRouter,
    config.vendors.gmxV2.depositVault,
    config.vendors.gmxV2.depositHandler,
    minHLPValueLossBPS,
  ]);

  await contract.deployed();
  console.log(`Deploying RebalanceHLPv2Service Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.services.rebalanceHLPToGMXV2 = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "RebalanceHLPv2Service",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
