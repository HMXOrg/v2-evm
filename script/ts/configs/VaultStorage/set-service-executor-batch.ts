import { VaultStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { compareAddress } from "../../utils/address";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const safeWrapper = new SafeWrapper(chainId, signers.deployer(chainId));
  const inputs = [
    {
      executorAddress: config.services.rebalanceHLP,
      isServiceExecutor: true,
    },
  ];

  const deployer = signers.deployer(chainId);
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);

  console.log("[configs/VaultStorage] VaultStorage: Set Service Executors...");
  const owner = await vaultStorage.owner();
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      vaultStorage.address,
      0,
      vaultStorage.interface.encodeFunctionData("setServiceExecutorBatch", [
        inputs.map((each) => each.executorAddress),
        inputs.map((each) => each.isServiceExecutor),
      ])
    );
    console.log(`[configs/VaultStorage] Tx: ${tx}`);
  } else {
    const tx = await vaultStorage.setServiceExecutorBatch(
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor)
    );
    console.log(`[configs/VaultStorage] Tx: ${tx.hash}`);
    await tx.wait(1);
  }
  console.log("[configs/VaultStorage] VaultStorage: Set Service Executors success!");
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
