import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { RebalanceHLPHandler__factory } from "../../../../typechain";
import signers from "../../entities/signers";

async function main(chainId: number) {
  const user = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
  const config = loadConfig(chainId);
  const handler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP, signers.deployer(42161));
  const tx = await handler.setWhiteListExecutor(user, true, { gasLimit: 10000000 });
  await tx.wait(1);
  console.log(`Set whitelist to address: ${user}`);
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
