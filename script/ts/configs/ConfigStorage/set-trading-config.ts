import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const tradingConfig = {
  fundingInterval: 1, // second
  devFeeRateBPS: 1000, // 10%
  minProfitDuration: 15, // second
  maxPosition: 10, // 10 positions per sub-account max
};

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Trading Config...");
  await (await configStorage.setTradingConfig(tradingConfig)).wait();
  console.log("> ConfigStorage: Set Trading Config success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
