import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const executor = "0x0578C797798Ae89b688Cd5676348344d7d0EC35E";

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Config Executor...");
  await (await configStorage.setConfigExecutor(executor, true)).wait();
  console.log("> ConfigStorage: Set Config Executor success!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
