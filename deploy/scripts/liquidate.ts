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
} from "../../typechain";
import { getConfig } from "../utils/config";
import { getPriceData } from "../utils/pyth";
import { getUpdatePriceData } from "../utils/price";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const priceUpdates = [
  1900.02, // ETH
  20000.29, // ETH
  1, // USDC
  1, // USDT
  1, // DAI
  137.3, // AAPL
  198.2, // JPY
];
const minPublishTime = Math.floor(new Date().valueOf() / 1000);
const publishTimeDiff = [
  0, // ETH
  0, // ETH
  0, // USDC
  0, // USDT
  0, // DAI
  0, // AAPL
  0, // JPY
];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const positionManager = (await ethers.getSigners())[1];

  const handler = BotHandler__factory.connect(config.handlers.bot, positionManager);
  const [priceUpdateData, publishTimeDiffUpdateData] = await getUpdatePriceData(
    deployer,
    priceUpdates,
    publishTimeDiff
  );
  console.log("Liquidate...");
  await (
    await handler.liquidate(
      "",
      priceUpdateData,
      publishTimeDiffUpdateData,
      minPublishTime,
      ethers.utils.formatBytes32String(""),
      {
        gasLimit: 300000000,
      }
    )
  ).wait();
  console.log("Liquidate Success!");
};

export default func;
func.tags = ["Liquidate"];
