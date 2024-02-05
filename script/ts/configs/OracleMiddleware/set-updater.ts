import { ethers } from "hardhat";
import { OracleMiddleware__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const updater = "0x0578C797798Ae89b688Cd5676348344d7d0EC35E";

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
