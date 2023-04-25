import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  CrossMarginHandler__factory,
  ERC20__factory,
  IPyth__factory,
  LimitTradeHandler__factory,
  MarketTradeHandler__factory,
  TradeService__factory,
} from "../typechain";
import { getConfig } from "./utils/config";
import { getPriceData } from "./utils/pyth";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  // await (await handler.setMinExecutionFee(30)).wait();
  const executionFee = await handler.minExecutionFee();
  console.log("Limit Order...");
  await (
    await handler.createOrder(
      0, // subAccountId
      0, // marketIndex
      ethers.utils.parseUnits("10", 30), // sizeDelta
      ethers.utils.parseUnits("1550", 30), // triggerPrice
      ethers.utils.parseUnits("0", 30), // acceptablePrice
      true, // triggerAboveThreshold
      executionFee,
      true, // reduceOnly (true to not flip position)
      config.tokens.usdc, // tpToken
      { value: executionFee }
    )
  ).wait();
  console.log("Limit Order Success!");
};

export default func;
func.tags = ["LimitOrder"];
