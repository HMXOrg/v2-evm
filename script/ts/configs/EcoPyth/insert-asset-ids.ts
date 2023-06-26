import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const assertIds = [ethers.utils.formatBytes32String("GLP")];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);

  console.log("> EcoPyth Insert Asset Ids...");
  await (await ecoPyth.insertAssetIds(assertIds)).wait();
  console.log("> EcoPyth Insert Asset Ids!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
