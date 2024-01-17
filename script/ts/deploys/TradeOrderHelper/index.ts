import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract(
    "TradeOrderHelper",
    [config.storages.config, config.storages.perp, config.oracles.middleware, config.services.trade],
    deployer
  );

  await contract.deployed();
  console.log(`[deploys/Dexter] Deploying TradeOrderHelper Contract`);
  console.log(`[deploys/Dexter] Deployed at: ${contract.address}`);

  config.helpers.tradeOrder = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "TradeOrderHelper",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
