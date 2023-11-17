import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { DistributeSTIPARBStrategy__factory } from "../../../../typechain";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, signer);

  const amount = 30289413075306806328952;
  const expiredAt = 1700733600; // Thu Nov 23 2023 10:00:00 GMT+0000

  console.log("[cmds/DistributeSTIPARBStrategy] execute...");
  const strat = DistributeSTIPARBStrategy__factory.connect(config.strategies.distributeSTIPARB, signer);
  if (compareAddress(await strat.owner(), config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      strat.address,
      0,
      strat.interface.encodeFunctionData("execute", [amount, expiredAt])
    );
    console.log(`[cmds/DistributeSTIPARBStrategy] Proposed tx: ${tx}`);
  } else {
    const tx = await strat.execute(amount, expiredAt);
    console.log(`[cmds/DistributeSTIPARBStrategy] Tx: ${tx.hash}`);
    await tx.wait();
    console.log(`[cmds/DistributeSTIPARBStrategy] Finished`);
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
