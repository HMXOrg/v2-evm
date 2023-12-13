import { PerpStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const windowLength = 15; // 15 invervals per window
  const eachInterval = 60; // each interval is 1 minute

  const perpStorage = PerpStorage__factory.connect(config.storages.perp, deployer);
  console.log(`[configs/PerpStorage] setMovingWindowConfig`);
  await ownerWrapper.authExec(
    perpStorage.address,
    perpStorage.interface.encodeFunctionData("setMovingWindowConfig", [windowLength, eachInterval])
  );
  console.log("[configs/PerpStorage] Finished");
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
