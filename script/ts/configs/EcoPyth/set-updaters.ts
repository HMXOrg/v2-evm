import { EcoPyth__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

async function main() {
  const config = loadConfig(42161);

  const inputs = [
    { updater: config.handlers.bot, isUpdater: true },
    { updater: config.handlers.crossMargin, isUpdater: true },
    { updater: config.handlers.limitTrade, isUpdater: true },
    { updater: config.handlers.liquidity, isUpdater: true },
  ];

  const deployer = signers.deployer(42161);
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);

  console.log("[configs/EcoPyth] Set Updaters...");
  await (
    await ecoPyth.setUpdaters(
      inputs.map((each) => each.updater),
      inputs.map((each) => each.isUpdater)
    )
  ).wait();
  console.log("[configs/EcoPyth] Set Updaters success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
