import { TradeOrderHelper__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const tradeOrderHelper = TradeOrderHelper__factory.connect(config.helpers.tradeOrder!, deployer);
  console.log(`[configs/TradeOrderHelper] Set Whitelisted Callers`);
  await ownerWrapper.authExec(
    tradeOrderHelper.address,
    tradeOrderHelper.interface.encodeFunctionData("setWhitelistedCaller", [config.handlers.intent!])
  );
  console.log("[configs/TradeOrderHelper] Finished");
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
