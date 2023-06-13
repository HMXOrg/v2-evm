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

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log("> LimitTradeHandler: setMinExecutionFee...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await (await limitTradeHandler.setMinExecutionFee(0)).wait();
  console.log("> LimitTradeHandler: setMinExecutionFee success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
