import { ethers, tenderly, upgrades, network, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const MIN_HLP_VALUE_LOSS_BPS = 50; // 0.5%

  const Contract = await ethers.getContractFactory("RebalanceHLPService", deployer);

  console.log(`[deploys/RebalanceHLPService] Deploying RebalanceHLPService Contract`);
  const contract = await upgrades.deployProxy(Contract, [
    config.storages.vault,
    config.storages.config,
    config.calculator,
    config.extension.switchCollateralRouter,
    MIN_HLP_VALUE_LOSS_BPS,
  ]);
  await contract.deployed();
  console.log(`[deploys/RebalanceHLPService] Deployed at: ${contract.address}`);

  config.services.rebalanceHLP = contract.address;
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
