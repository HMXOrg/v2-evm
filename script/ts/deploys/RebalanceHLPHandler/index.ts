import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { RebalanceHLPHandler__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const minHLPValueLossBPS = 50; // 0.5 %

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("RebalanceHLPHandler", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.services.rebalanceHLP,
    config.calculator,
    config.storages.config,
    config.oracles.ecoPyth,
    minHLPValueLossBPS,
  ]);
  await contract.deployed();

  console.log(`Deploying RebalanceHLPHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  const user = "0x05bDb067630e19e7e4aBF3436AF0e176Be573D32";

  config.handlers.rebalanceHLP = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "RebalanceHLPHandler",
  });

  const handler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP, signers.deployer(42161));
  const tx = await handler.setWhiteListExecutor(user, true, { gasLimit: 10000000 });
  await tx.wait(1);
  console.log(`Set whitelist to address: ${user}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
