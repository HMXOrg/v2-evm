import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);

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
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Proposing to set service executors...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setServiceExecutors", [
      inputs.map((each) => each.contractAddress),
      inputs.map((each) => each.executorAddress),
      inputs.map((each) => each.isServiceExecutor),
    ])
  );
  console.log("[config/ConfigStorage] Done");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
