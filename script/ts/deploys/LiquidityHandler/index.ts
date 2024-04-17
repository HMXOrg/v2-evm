import { ethers, run, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const minExecutionFee = ethers.utils.parseEther("0.001"); // 0.001 ETH
const maxExecutionChunk = 100;

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LiquidityHandler", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.services.liquidity,
    config.oracles.ecoPyth2,
    minExecutionFee,
    maxExecutionChunk,
  ]);
  await contract.deployed();
  console.log(`Deploying LiquidityHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.liquidity = contract.address;
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
