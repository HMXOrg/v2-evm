import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, network } from "hardhat";
import {
  Calculator__factory,
  ConfigStorage__factory,
  OracleMiddleware__factory,
  PerpStorage__factory,
} from "../../typechain";
import { getConfig } from "../utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const perpStorage = PerpStorage__factory.connect(config.storages.perp, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const oracleMiddleware = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);
  const calculator = Calculator__factory.connect(config.calculator, deployer);
  console.log(await calculator.getFundingRateVelocity(0));
  const positions = await perpStorage.getActivePositions(100, 0);
  console.log(positions);
  let totalPnL = BigNumber.from(0);
  let markets = [BigNumber.from(0), BigNumber.from(0), BigNumber.from(0), BigNumber.from(0)];
  // const blockTag = { blockTag: 23205839 };
  const blockTag = {};
  for (let i = 0; i < positions.length; i++) {
    const position = positions[i];
    const market = await perpStorage.markets(position.marketIndex, blockTag);
    const marketSkew = market.longPositionSize.sub(market.shortPositionSize);
    const marketConfig = await configStorage.marketConfigs(position.marketIndex, blockTag);
    const closePrice = (
      await oracleMiddleware.unsafeGetLatestAdaptivePriceWithMarketStatus(
        marketConfig.assetId,
        true,
        marketSkew,
        position.positionSizeE30.mul(-1),
        ethers.utils.parseUnits("300000000", 30),
        0,
        blockTag
      )
    )._adaptivePrice;
    const pnl = getPnL(closePrice, position.avgEntryPriceE30, position.positionSizeE30);
    console.log(position.marketIndex, position.positionSizeE30.gt(0), "PnL", ethers.utils.formatUnits(pnl, 30));
    totalPnL = totalPnL.add(pnl);
  }
  console.log("Loop PnL", ethers.utils.formatUnits(totalPnL, 30));
  console.log("Global PnL", ethers.utils.formatUnits(await calculator.getGlobalPNLE30(blockTag), 30));
  // console.log(
  //   "Market 0",
  //   ethers.utils.formatUnits(markets[0], 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(0, true), 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(0, false), 30)
  // );
  // console.log(
  //   "Market 1",
  //   ethers.utils.formatUnits(markets[1], 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(1, true), 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(1, false), 30)
  // );
  // console.log(
  //   "Market 2",
  //   ethers.utils.formatUnits(markets[2], 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(2, true), 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(2, false), 30)
  // );
  // console.log(
  //   "Market 3",
  //   ethers.utils.formatUnits(markets[3], 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(3, true), 30),
  //   ethers.utils.formatUnits(await calculator.getGlobalMarketPnl(3, false), 30)
  // );
};

function getPnL(closePrice: BigNumber, averagePrice: BigNumber, size: BigNumber): BigNumber {
  return closePrice.sub(averagePrice).mul(size).div(averagePrice);
}

function calculateAdaptivePrice(
  marketSkew: BigNumber,
  maxSkewScaleUSD: BigNumber,
  sizeDelta: BigNumber,
  price: BigNumber
): BigNumber {
  console.log("marketSkew", marketSkew);
  console.log("maxSkewScaleUSD", maxSkewScaleUSD);
  console.log("sizeDelta", sizeDelta);
  console.log("price", price);
  const premium = marketSkew.mul(ONE_USD).div(maxSkewScaleUSD);
  const premiumAfter = marketSkew.add(sizeDelta).mul(ONE_USD).div(maxSkewScaleUSD);
  const premiumMedian = premium.add(premiumAfter).div(2);
  return price.mul(ONE_USD.add(premiumMedian)).div(ONE_USD);
}

export default func;
func.tags = ["ReadPositions"];
