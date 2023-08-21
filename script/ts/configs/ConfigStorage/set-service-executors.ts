import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, signers.deployer(chainId));
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      contractAddress: config.services.rebalanceHLP,
      executorAddress: config.handlers.rebalanceHLP,
      isServiceExecutor: true,
    },
  ];

  console.log("[configs/ConfigStorage] Set Service Executors...");
  const owner = await configStorage.owner();
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      configStorage.address,
      0,
      configStorage.interface.encodeFunctionData("setServiceExecutors", [
        inputs.map((each) => each.contractAddress),
        inputs.map((each) => each.executorAddress),
        inputs.map((each) => each.isServiceExecutor),
      ])
    );
    console.log(`[configs/ConfigStorage] Tx: ${tx}`);
  } else {
    const tx = await configStorage.setServiceExecutors(
      inputs.map((each) => each.contractAddress),
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor)
    );
    console.log(`[configs/ConfigStorage] Tx: ${tx.hash}`);
    await tx.wait(1);
  }
  console.log("[configs/ConfigStorage] Set Service Executors success!");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
