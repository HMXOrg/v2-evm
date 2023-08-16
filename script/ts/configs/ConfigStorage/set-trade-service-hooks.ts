import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import signers from "../../entities/signers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] ConfigStorage setTradeServiceHooks...");
  const tx = await safeWrapper.proposeTransaction(
    configStorage.address,
    0,
    configStorage.interface.encodeFunctionData("setTradeServiceHooks", [
      [config.hooks.tlc, config.hooks.tradingStaking],
    ])
  );
  console.log(`[config/ConfigStorage] Proposed ${tx} to setTradeServiceHooks`);
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
