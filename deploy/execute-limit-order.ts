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

const BigNumber = ethers.BigNumber;
const config = getConfig();

const priceIds = [
  "0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6", // ETH/USD
];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  const pyth = IPyth__factory.connect(config.oracles.pyth, deployer);
  const priceData = await getPriceData(priceIds);
  // const storage = VaultStorage__factory.connect(config.storages.vault, deployer);
  // await (await storage.setServiceExecutors(config.services.trade, true)).wait();
  console.log("Execute Limit Order...");
  await (
    await handler.executeOrder(deployer.address, 0, 2, deployer.address, priceData, { gasLimit: 10000000 })
  ).wait();
  console.log("Execute Limit Order Success!");
};

export default func;
func.tags = ["ExecuteLimitOrder"];
