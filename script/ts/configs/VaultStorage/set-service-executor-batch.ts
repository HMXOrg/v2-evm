import { ethers } from "hardhat";
import {
  ConfigStorage__factory,
  EcoPyth__factory,
  PythAdapter__factory,
  VaultStorage__factory,
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [
  {
    executorAddress: config.services.liquidity,
    isServiceExecutor: true,
  },
  {
    executorAddress: config.services.crossMargin,
    isServiceExecutor: true,
  },
  {
    executorAddress: config.services.trade,
    isServiceExecutor: true,
  },
  {
    executorAddress: config.helpers.trade,
    isServiceExecutor: true,
  },
  {
    executorAddress: config.services.liquidation,
    isServiceExecutor: true,
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);

  console.log("> VaultStorage: Set Service Executors...");
  await (
    await vaultStorage.setServiceExecutorBatch(
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor)
    )
  ).wait();
  console.log("> VaultStorage: Set Service Executors success!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
