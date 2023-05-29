import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  IPyth__factory,
  LimitTradeHandler__factory,
  LiquidityHandler__factory,
  MockPyth__factory,
  PythAdapter__factory,
} from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const orderExecutor = "0x0578C797798Ae89b688Cd5676348344d7d0EC35E";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  console.log("> LiquidityHandler: Set Order Executor...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  await (await handler.setOrderExecutor(orderExecutor, true)).wait();
  console.log("> LiquidityHandler: Set Order Executor success!");
};
export default func;
func.tags = ["LiquidityHandlerSetOrderExecutor"];
