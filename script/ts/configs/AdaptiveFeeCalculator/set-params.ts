import { AdaptiveFeeCalculator__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const k1 = 12500;
  const k2 = 50;

  const adaptiveFeeCalculator = AdaptiveFeeCalculator__factory.connect(config.adaptiveFeeCalculator, deployer);
  console.log(`[configs/AdaptiveFeeCalculator] setParams`);
  await ownerWrapper.authExec(
    adaptiveFeeCalculator.address,
    adaptiveFeeCalculator.interface.encodeFunctionData("setParams", [k1, k2])
  );
  console.log("[configs/AdaptiveFeeCalculator] Finished");
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
