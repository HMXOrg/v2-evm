import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { StakedGlpStrategy__factory } from "../../../../typechain";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);

  console.log("[StakedGlpStrategy] Reinvest...");
  const stakedGlpStrategy = StakedGlpStrategy__factory.connect(config.strategies.stakedGlpStrategy, signer);
  const tx = await stakedGlpStrategy.execute();
  console.log(`[StakedGlpStrategy] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[StakedGlpStrategy] Finished");
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
