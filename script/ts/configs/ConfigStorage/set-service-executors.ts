import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import signers from "../../entities/signers";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [
    {
      contractAddress: config.services.rebalanceHLP,
      executorAddress: config.handlers.rebalanceHLP,
      isServiceExecutor: true,
    },
  ];

  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(42161, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Proposing to set service executors...");
  const tx = await safeWrapper.proposeTransaction(
    configStorage.address,
    0,
    configStorage.interface.encodeFunctionData("setServiceExecutors", [
      inputs.map((each) => each.contractAddress),
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor),
    ])
  );
  console.log(`[config/ConfigStorage] Proposed tx: ${tx}`);
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
