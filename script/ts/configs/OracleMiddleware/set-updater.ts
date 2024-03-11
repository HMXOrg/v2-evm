import { ethers } from "hardhat";
import { OracleMiddleware__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);

  const updater = "0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E";

  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/OracleMiddleware] Set Updater...");
  await ownerWrapper.authExec(oracle.address, oracle.interface.encodeFunctionData("setUpdater", [updater, true]));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
