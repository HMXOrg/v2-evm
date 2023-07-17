import { VaultStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const inputs = [
    {
      executorAddress: config.handlers.bot,
      isServiceExecutor: true,
    },
  ];

  const deployer = signers.deployer(chainId);
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);

  console.log("[configs/VaultStorage] VaultStorage: Set Service Executors...");
  await (
    await vaultStorage.setServiceExecutorBatch(
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor)
    )
  ).wait();
  console.log("[configs/VaultStorage] VaultStorage: Set Service Executors success!");
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
