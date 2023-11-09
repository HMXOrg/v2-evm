import { TradeHelper__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  const maxFeeBps = 500;

  const tradeHelper = TradeHelper__factory.connect(config.helpers.trade, deployer);
  const owner = await tradeHelper.owner();
  console.log(`[configs/TradeHelper] setMaxAdaptiveFeeBps`);
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      tradeHelper.address,
      0,
      tradeHelper.interface.encodeFunctionData("setMaxAdaptiveFeeBps", [maxFeeBps])
    );
    console.log(`[configs/TradeHelper] Proposed tx: ${tx}`);
  } else {
    const tx = await tradeHelper.setMaxAdaptiveFeeBps(maxFeeBps);
    console.log(`[configs/TradeHelper] Tx: ${tx}`);
    await tx.wait();
  }
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
