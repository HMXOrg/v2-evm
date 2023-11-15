import { PerpStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  const windowLength = 15; // 15 invervals per window
  const eachInterval = 60; // each interval is 1 minute

  const perpStorage = PerpStorage__factory.connect(config.storages.perp, deployer);
  const owner = await perpStorage.owner();
  console.log(`[configs/PerpStorage] setMovingWindowConfig`);
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      perpStorage.address,
      0,
      perpStorage.interface.encodeFunctionData("setMovingWindowConfig", [windowLength, eachInterval])
    );
    console.log(`[configs/PerpStorage] Proposed tx: ${tx}`);
  } else {
    const tx = await perpStorage.setMovingWindowConfig(windowLength, eachInterval);
    console.log(`[configs/PerpStorage] Tx: ${tx}`);
    await tx.wait();
  }
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
