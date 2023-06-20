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
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const positionManagers = ["0x3231C08B500bb26e0654cb0338F135CeD44d6B84"];

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log("> BotHandler: Set Position Manager...");
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);
  await (await botHandler.setPositionManagers(positionManagers, true)).wait();
  console.log("> BotHandler: Set Position Manager success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
