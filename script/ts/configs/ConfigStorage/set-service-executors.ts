import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [
  {
    contractAddress: config.services.crossMargin,
    executorAddress: config.handlers.crossMargin,
    isServiceExecutor: true,
  },
  {
    contractAddress: config.services.liquidity,
    executorAddress: config.handlers.liquidity,
    isServiceExecutor: true,
  },
  {
    contractAddress: config.services.liquidation,
    executorAddress: config.handlers.bot,
    isServiceExecutor: true,
  },
  {
    contractAddress: config.services.trade,
    executorAddress: config.handlers.limitTrade,
    isServiceExecutor: true,
  },
  {
    contractAddress: config.services.trade,
    executorAddress: config.handlers.bot,
    isServiceExecutor: true,
  },
  {
    contractAddress: config.helpers.trade,
    executorAddress: config.services.trade,
    isServiceExecutor: true,
  },
  {
    contractAddress: config.helpers.trade,
    executorAddress: config.services.liquidation,
    isServiceExecutor: true,
  },
  {
    contractAddress: config.services.rebalanceHLP,
    executorAddress: config.handlers.rebalanceHLP,
    isServiceExecutor: true,
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Service Executors...");
  await (
    await configStorage.setServiceExecutors(
      inputs.map((each) => each.contractAddress),
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor)
    )
  ).wait();
  console.log("> ConfigStorage: Set Service Executors success!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
