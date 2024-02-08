import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying LimitTradeHelper Contract`);
  const Contract = await ethers.getContractFactory("LimitTradeHelper", deployer);
  const contract = await Contract.deploy(config.storages.config, config.storages.perp);
  await contract.deployed();
  console.log(`Deployed at: ${contract.address}`);

  config.helpers.limitTrade = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
    constructorArguments: [config.storages.config, config.storages.perp],
  });
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
