import { Command } from "commander";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  console.log(`[Safe/signPendingTransactions] Executing pending transactions...`);
  await safeWrapper.signPendingTransactions();
  console.log(`[Safe/signPendingTransactions] Done`);
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exitCode = 0;
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
