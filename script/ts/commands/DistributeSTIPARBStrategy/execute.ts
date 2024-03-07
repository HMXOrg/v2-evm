import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { DistributeSTIPARBStrategy__factory } from "../../../../typechain";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, signer);

  const amount = "6496648404417764547031";
  const expiredAt = 1710410400; // Thu Mar 14 2024 10:00:00 GMT+0000

  console.log(`[cmds/DistributeSTIPARBStrategy] Feeding ${ethers.utils.formatEther(amount)} ARB...`);
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
