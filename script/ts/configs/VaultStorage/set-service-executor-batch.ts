import { getChainId } from "hardhat";
import { VaultStorage__factory } from "../../../../typechain";
import { getConfig, loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

const config = getConfig();

const inputs = [
  {
    executorAddress: config.rewardDistributor,
    isServiceExecutor: true,
  },
];

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
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
