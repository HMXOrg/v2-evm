import { TradeHelper__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const maxFeeBps = 50; // 0.5% max fee

  const tradeHelper = TradeHelper__factory.connect(config.helpers.trade, deployer);
  console.log(`[configs/TradeHelper] setMaxAdaptiveFeeBps`);
  await ownerWrapper.authExec(
    tradeHelper.address,
    tradeHelper.interface.encodeFunctionData("setMaxAdaptiveFeeBps", [maxFeeBps])
  );
  console.log("[configs/TradeHelper] Finished");
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
