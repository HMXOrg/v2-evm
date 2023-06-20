import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  IPyth__factory,
  LimitTradeHandler__factory,
  MockPyth__factory,
  PythAdapter__factory,
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const orderExecutor = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log("> LimitTradeHandler: Set Order Executor...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await (await limitTradeHandler.setOrderExecutor(orderExecutor, true)).wait();
  console.log("> LimitTradeHandler: Set Order Executor success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
