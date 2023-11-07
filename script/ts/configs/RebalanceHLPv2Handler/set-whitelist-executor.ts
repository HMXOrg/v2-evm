import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { RebalanceHLPv2Handler__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const user = config.safe;
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  console.log(`[configs/RebalanceHLPHandler] Set whitelist to address: ${user}`);
  const handler = RebalanceHLPv2Handler__factory.connect(config.handlers.rebalanceHLPv2, deployer);
  if (compareAddress(await handler.owner(), config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      handler.address,
      0,
      handler.interface.encodeFunctionData("setWhitelistExecutor", [user, true])
    );
    console.log(`[configs/RebalanceHLPHandler] Proposed tx: ${tx}`);
  } else {
    const tx = await handler.setWhitelistExecutor(user, true);
    console.log(`[configs/RebalanceHLPHandler] Executed tx: ${tx.hash}`);
    await tx.wait();
  }
}

const prog = new Command();
prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
