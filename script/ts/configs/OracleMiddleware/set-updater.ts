import { ethers } from "hardhat";
import { OracleMiddleware__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const updater = "0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E";

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("> OracleMiddleware Set Updater...");
  await (await oracle.setUpdater(updater, true)).wait();
  console.log("> OracleMiddleware Set Updater success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
