import { EcoPyth__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main() {
  const config = loadConfig(42161);

  const inputs = [{ updater: "0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872", isUpdater: true }];

  const deployer = signers.deployer(42161);
  const safeWrapper = new SafeWrapper(42161, deployer);
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);

  console.log("[configs/EcoPyth] Set Updaters...");
  const tx = await safeWrapper.proposeTransaction(
    ecoPyth.address,
    0,
    ecoPyth.interface.encodeFunctionData("setUpdaters", [
      inputs.map((each) => each.updater),
      inputs.map((each) => each.isUpdater),
    ])
  );
  console.log(`[configs/EcoPyth] Tx: ${tx}`);
  console.log("[configs/EcoPyth] Set Updaters success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
