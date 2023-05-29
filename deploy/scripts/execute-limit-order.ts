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
} from "../../typechain";
import { getConfig } from "../utils/config";
import { getPriceData } from "../utils/pyth";
import { getUpdatePriceData } from "../utils/price";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const priceUpdates = [
  1900.02, // ETH
  20000.29, // BTC
  1, // USDC
  1, // USDT
  1, // DAI
  137.3, // AAPL
  198.2, // JPY
];
const minPublishTime = Math.floor(new Date().valueOf() / 1000);
const publishTimeDiff = [
  0, // ETH
  0, // BTC
  0, // USDC
  0, // USDT
  0, // DAI
  0, // AAPL
  0, // JPY
];

const mainAccount = "0x6a5d2bf8ba767f7763cd342cb62c5076f9924872";
const subAccountId = 0;
const orderIndex = 0;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const address = BigNumber.from(mainAccount).xor(subAccountId).toHexString();

  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  const [priceUpdateData, publishTimeDiffUpdateData] = await getUpdatePriceData(
    deployer,
    priceUpdates,
    publishTimeDiff,
    true
  );

  console.log("Execute Limit Order...");
  await (
    await handler.executeOrder(
      mainAccount,
      subAccountId,
      orderIndex,
      deployer.address,
      priceUpdateData,
      publishTimeDiffUpdateData,
      minPublishTime,
      ethers.utils.formatBytes32String(""),
      { gasLimit: 10000000 }
    )
  ).wait();
  console.log("Execute Limit Order Success!");
};

export default func;
func.tags = ["ExecuteLimitOrder"];
