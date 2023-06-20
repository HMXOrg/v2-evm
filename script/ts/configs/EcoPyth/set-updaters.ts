import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [
  { updater: config.handlers.bot, isUpdater: true },
  { updater: config.handlers.crossMargin, isUpdater: true },
  { updater: config.handlers.limitTrade, isUpdater: true },
  { updater: config.handlers.liquidity, isUpdater: true },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);

  console.log("> EcoPyth Set Updaters...");
  await (
    await ecoPyth.setUpdaters(
      inputs.map((each) => each.updater),
      inputs.map((each) => each.isUpdater)
    )
  ).wait();
  console.log("> EcoPyth Set Updaters success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
