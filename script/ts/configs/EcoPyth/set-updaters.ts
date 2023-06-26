import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const inputs = [{ updater: "0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872", isUpdater: true }];

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
