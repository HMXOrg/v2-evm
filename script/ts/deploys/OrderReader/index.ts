import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("OrderReader", deployer);
  const contract = await Contract.deploy(
    config.storages.config,
    config.storages.perp,
    config.oracles.middleware,
    config.handlers.limitTrade
  );
  await contract.deployed();
  console.log(`Deploying OrderReader Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.reader.order = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: config.reader.order,
    constructorArguments: [
      config.storages.config,
      config.storages.perp,
      config.oracles.middleware,
      config.handlers.limitTrade,
    ],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
