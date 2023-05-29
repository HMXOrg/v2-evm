import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  ConfigStorage__factory,
  CrossMarginHandler__factory,
  IPyth__factory,
  LimitTradeHandler__factory,
  MockPyth__factory,
  PythAdapter__factory,
} from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  console.log("> ConfigStorage: Set Service Executor...");
  const storage = ConfigStorage__factory.connect(config.storages.config, deployer);
  await (await storage.setServiceExecutor(config.services.trade, config.handlers.limitTrade, true)).wait();
  console.log("> ConfigStorage: Set Service Executor success!");
};
export default func;
func.tags = ["ConfigStorageSeServiceExecutor"];
