import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { Calculator__factory, ConfigStorage__factory, PerpStorage__factory } from "../../../../typechain";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const perpStorage = PerpStorage__factory.connect(config.storages.perp, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const calculator = Calculator__factory.connect(config.calculator, deployer);

  const marketName = [
    "ETHUSD",
    "BTCUSD",
    "AAPLUSD",
    "JPYUSD",
    "XAUUSD",
    "AMZNUSD",
    "MSFTUSD",
    "TSLAUSD",
    "EURUSD",
    "XAGUSD",
    "AUDUSD",
    "GBPUSD",
    "ADAUSD",
    "MATICUSD",
    "SUIUSD",
    "ARBUSD",
    "OPUSD",
    "LTCUSD",
    "COINUSD",
    "GOOGUSD",
    "BNBUSD",
    "SOLUSD",
    "QQQUSD",
    "XRPUSD",
  ];
  const marketIndices = [17];
  for (let i = 0; i < marketIndices.length; i++) {
    const marketIndex = marketIndices[i];
    const market = await perpStorage.getMarketByIndex(marketIndex);
    const fundingRateVelocity = await calculator.getFundingRateVelocity(marketIndex);
    const config = await configStorage.getMarketConfigByIndex(marketIndex);
    console.log(`Market: ${marketName[marketIndex]}`);
    console.log(`1H Funding Rate: ${ethers.utils.formatUnits(market.currentFundingRate.div(24).mul(100), 18)}%`);
    console.log(`1Y Funding Rate: ${ethers.utils.formatUnits(market.currentFundingRate.mul(365).mul(100), 18)}%`);
    console.log(`1H Funding Rate Velocity: ${ethers.utils.formatUnits(fundingRateVelocity.div(24).mul(100), 18)}%`);
    console.log(`Long Unrealized Funding Fee: ${ethers.utils.formatUnits(market.accumFundingLong, 30)} USD`);
    console.log(`Short Unrealized Funding Fee: ${ethers.utils.formatUnits(market.accumFundingShort, 30)} USD`);
    console.log(`Max Funding Rate: ${ethers.utils.formatUnits(config.fundingRate.maxFundingRate, 18)}`);
    console.log(`Max Skew Scale: ${ethers.utils.formatUnits(config.fundingRate.maxSkewScaleUSD, 30)} USD`);
    console.log();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
