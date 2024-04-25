import { LimitTradeHandler__factory } from "../../../../typechain";
import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { ethers } from "ethers";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, deployer);

  const minExecutionTimestamp = 60 * 3; // 3 mins

  console.log("[LimitTradeHandler] setMinExecutionTimestamp...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  const tx = await safeWrapper.proposeTransaction(
    limitTradeHandler.address,
    0,
    limitTradeHandler.interface.encodeFunctionData("setMinExecutionTimestamp", [minExecutionTimestamp])
  );
  console.log(`[LimitTradeHandler] Tx: ${tx}`);
  console.log("[LimitTradeHandler] setMinExecutionTimestamp success!");
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
