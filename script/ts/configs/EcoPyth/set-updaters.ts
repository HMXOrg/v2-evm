import { EcoPyth__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const safeWrapper = new SafeWrapper(chainId, signers.deployer(chainId));

  const inputs = [{ updater: config.handlers.rebalanceHLP, isUpdater: true }];

  const deployer = signers.deployer(chainId);
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);

  console.log("[configs/EcoPyth] Set Updaters...");
  const owner = await ecoPyth.owner();
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      ecoPyth.address,
      0,
      ecoPyth.interface.encodeFunctionData("setUpdaters", [
        inputs.map((each) => each.updater),
        inputs.map((each) => each.isUpdater),
      ])
    );
    console.log(`[configs/EcoPyth] Tx: ${tx}`);
  } else {
    const tx = await ecoPyth.setUpdaters(
      inputs.map((each) => each.updater),
      inputs.map((each) => each.isUpdater)
    );
    console.log(`[configs/EcoPyth] Tx: ${tx.hash}`);
    await tx.wait(1);
  }
  console.log("[configs/EcoPyth] Set Updaters success!");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
