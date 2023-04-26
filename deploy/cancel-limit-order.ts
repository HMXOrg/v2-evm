import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  CrossMarginHandler__factory,
  ERC20__factory,
  IPyth__factory,
  LimitTradeHandler__factory,
  MarketTradeHandler__factory,
  PerpStorage__factory,
  TradeService__factory,
  VaultStorage__factory,
} from "../typechain";
import { getConfig } from "./utils/config";
import { getPriceData } from "./utils/pyth";
import { getUpdatePriceData } from "./utils/price";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const subAccountId = 0;
const orderIndex = 0;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const address = BigNumber.from(deployer.address).xor(subAccountId).toHexString();

  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);

  console.log("Cancel Limit Order...");
  await (await handler.cancelOrder(subAccountId, orderIndex, { gasLimit: 10000000 })).wait();
  console.log(`Order Index: ${await handler.limitOrdersIndex(address)}`);
  console.log("Cancel Limit Order Success!");
};

export default func;
func.tags = ["CancelLimitOrder"];
