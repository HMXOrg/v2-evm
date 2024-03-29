import { ethers } from "hardhat";
import {
  ConfigStorage__factory,
  EcoPyth__factory,
  PerpStorage__factory,
  PythAdapter__factory,
  VaultStorage__factory,
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [
  {
    executorAddress: config.rewardDistributor,
    isServiceExecutor: true,
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const perpStorage = PerpStorage__factory.connect(config.storages.perp, deployer);

  console.log("> PerpStorage: Set Service Executors...");
  await (
    await perpStorage.setServiceExecutorBatch(
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor)
    )
  ).wait();
  console.log("> PerpStorage: Set Service Executors success!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
