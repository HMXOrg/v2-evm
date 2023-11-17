import { ERC20ApproveStrategy__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  const whitelistedExecutor = config.strategies.distributeSTIPARB;

  const strat = ERC20ApproveStrategy__factory.connect(config.strategies.erc20Approve, deployer);
  const owner = await strat.owner();
  console.log(`[configs/ERC20ApproveStrategy] Set Whitelisted Executor`);
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      strat.address,
      0,
      strat.interface.encodeFunctionData("setWhitelistedExecutor", [whitelistedExecutor, true])
    );
    console.log(`[configs/ERC20ApproveStrategy] Proposed tx: ${tx}`);
  } else {
    const tx = await strat.setWhitelistedExecutor(whitelistedExecutor, true);
    console.log(`[configs/ERC20ApproveStrategy] Tx: ${tx}`);
    await tx.wait();
  }
  console.log("[configs/ERC20ApproveStrategy] Finished");
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
