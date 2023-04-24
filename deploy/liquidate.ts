import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import {
  BotHandler__factory,
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
  "0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b", // BTC/USD
  "0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722", // USDC/USD
  "0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588", // USDT/USD
  "0x87a67534df591d2dd5ec577ab3c75668a8e3d35e92e27bf29d9e2e52df8de412", // DAI/USD
];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const positionManager = (await ethers.getSigners())[1];

  const handler = BotHandler__factory.connect(config.handlers.bot, positionManager);
  const pyth = IPyth__factory.connect(config.oracles.pyth, positionManager);
  const priceData = await getPriceData(priceIds);
  const updateFee = await pyth.getUpdateFee(priceData);
  console.log("Liquidate...");
  await (
    await handler.liquidate("", [], {
      value: updateFee,
      gasLimit: 300000000,
    })
  ).wait();
  console.log("Liquidate Success!");
};

export default func;
func.tags = ["Liquidate"];
