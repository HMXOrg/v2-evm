import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("TradeOrderHelper", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.storages.config,
    config.storages.perp,
    config.oracles.middleware,
    config.services.trade,
  ]);
  await contract.deployed();
  console.log(`Deploying TradeOrderHelper Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.helpers.tradeOrder = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "TradeHelper",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
