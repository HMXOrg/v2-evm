import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { DistributeSTIPARBStrategy__factory } from "../../../../typechain";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, signer);

  const amount = "49183091866576886804658";
  const expiredAt = 1701943200; // Thu Dec 07 2023 10:00:00 GMT+0000

  console.log("[cmds/DistributeSTIPARBStrategy] execute...");
  const strat = DistributeSTIPARBStrategy__factory.connect(config.strategies.distributeSTIPARB, signer);
  const tx = await safeWrapper.proposeTransaction(
    strat.address,
    0,
    strat.interface.encodeFunctionData("execute", [amount, expiredAt])
  );
  console.log(`[cmds/DistributeSTIPARBStrategy] Proposed tx: ${tx}`);
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
