import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import signers from "../../entities/signers";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [
    {
      contractAddress: config.services.rebalanceHLPv2,
      executorAddress: config.handlers.rebalanceHLPv2,
      isServiceExecutor: true,
    },
  ];

  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Proposing to set service executors...");
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
    console.log(`[config/ConfigStorage] Proposed tx: ${tx}`);
  } else {
    const tx = await configStorage.setServiceExecutors(
      inputs.map((each) => each.contractAddress),
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor),
      {
        gasLimit: 10000000,
      }
    );
    console.log(`[config/ConfigStorage] tx: ${tx.hash}`);
    await tx.wait();
  }
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
