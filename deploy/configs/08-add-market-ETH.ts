import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set PnL Factor...");
  // default market config
  IConfigStorage.MarketConfig memory _newMarketConfig;
  IConfigStorage.FundingRate memory _newFundingRateConfig;

  _newFundingRateConfig.maxSkewScaleUSD = 3_000_000 * DOLLAR;
  _newFundingRateConfig.maxFundingRate = 0.00000116 * 1e18; // 10% per day

  _newMarketConfig.assetId = _assetId;
  _newMarketConfig.increasePositionFeeRateBPS = _managePositionFee;
  _newMarketConfig.decreasePositionFeeRateBPS = _managePositionFee;
  _newMarketConfig.initialMarginFractionBPS = _imf;
  _newMarketConfig.maintenanceMarginFractionBPS = _mmf;
  _newMarketConfig.maxProfitRateBPS = 90000; // 900%
  _newMarketConfig.minLeverageBPS = 11000; // 110%
  _newMarketConfig.assetClass = _assetClass;
  _newMarketConfig.allowIncreasePosition = true;
  _newMarketConfig.active = true;
  _newMarketConfig.fundingRate = _newFundingRateConfig;
  _newMarketConfig.maxLongPositionSize = 10_000_000 * 1e30;
  _newMarketConfig.maxShortPositionSize = 10_000_000 * 1e30;

  return configStorage.addMarketConfig(_newMarketConfig);
  console.log("> ConfigStorage: Set PnL Factor success!");
};
export default func;
func.tags = ["SetPnLFactor"];
