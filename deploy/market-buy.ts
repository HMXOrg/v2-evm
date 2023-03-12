import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  CrossMarginHandler__factory,
  ERC20__factory,
  IPyth__factory,
  MarketTradeHandler__factory,
  TradeService__factory,
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

  const handler = MarketTradeHandler__factory.connect(config.handlers.marketTrade, deployer);
  const pyth = IPyth__factory.connect(config.oracle.pyth, deployer);
  const priceData = await getPriceData(priceIds);
  const updateFee = await pyth.getUpdateFee(priceData);
  console.log("Market Buy...");
  await handler.buy(deployer.address, 0, 0, ethers.utils.parseUnits("10", 30), config.tokens.usdc, priceData, {
    value: 1,
  });
  console.log("Market Buy Success!");
};

export default func;
func.tags = ["MarketBuy"];
