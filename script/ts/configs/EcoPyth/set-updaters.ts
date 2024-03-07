import { EcoPyth__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [{ updater: config.handlers.rebalanceHLP!, isUpdater: true }];

  const deployer = signers.deployer(chainId);
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2!, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/EcoPyth] Proposing to set updaters...");
  await ownerWrapper.authExec(
    ecoPyth.address,
    ecoPyth.interface.encodeFunctionData("setUpdaters", [
      inputs.map((each) => each.updater),
      inputs.map((each) => each.isUpdater),
    ])
  );
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
