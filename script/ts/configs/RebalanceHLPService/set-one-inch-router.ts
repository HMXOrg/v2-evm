import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { RebalanceHLPService__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  console.log(`[configs/RebalanceHLPHandler] Set one inch router`);
  const handler = RebalanceHLPService__factory.connect(config.handlers.rebalanceHLP, deployer);
  const tx = await safeWrapper.proposeTransaction(
    handler.address,
    0,
    handler.interface.encodeFunctionData("setOneInchRouter", [config.vendors.oneInch.router])
  );
  console.log(`[configs/RebalanceHLPHandler] Proposed tx: ${tx}`);
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
