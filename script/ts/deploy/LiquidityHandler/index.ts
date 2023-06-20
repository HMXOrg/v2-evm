import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const minExecutionOrderFee = 30;
const maxExecutionChuck = 100;

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LiquidityHandler", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.services.liquidity,
    config.oracles.ecoPyth,
    minExecutionOrderFee,
    maxExecutionChuck,
  ]);
  await contract.deployed();
  console.log(`Deploying LiquidityHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.liquidity = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "LiquidityHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
