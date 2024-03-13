import { ethers, run, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const tradingStaking = config.staking.trading;

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("TradingStakingHook", deployer);

  console.log(`[deploys/TradingStakingHook] Deploying TradingStakingHook Contract`);
  const contract = await upgrades.deployProxy(Contract, [tradingStaking, config.services.trade]);
  await contract.deployed();
  console.log(`[deploys/TradingStakingHook] Deployed at: ${contract.address}`);

  config.hooks.tradingStaking = contract.address;
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
