import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  BotHandler__factory,
  IPyth__factory,
  LimitTradeHandler__factory,
  MockPyth__factory,
  PythAdapter__factory,
} from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const positionManagers = ["0x0578C797798Ae89b688Cd5676348344d7d0EC35E"];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  console.log("> BotHandler: Set Position Manager...");
  const handler = BotHandler__factory.connect(config.handlers.bot, deployer);
  await (await handler.setPositionManagers(positionManagers, true)).wait();
  console.log("> BotHandler: Set Position Manager success!");
};
export default func;
func.tags = ["BotHandlerSetPositionManager"];
