import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const cryptoAssetClass = 0;
const equityAssetClass = 1;
const forexAssetClass = 2;
const commoditiesAssetClass = 3;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Add Market Config...");
  await (
    await configStorage.addMarketConfig({
      assetId: ethers.utils.formatBytes32String("XAU"),
      increasePositionFeeRateBPS: 10, // 0.1%
      decreasePositionFeeRateBPS: 10, // 0.1%
      initialMarginFractionBPS: 100, // IMF = 1%, Max leverage = 100
      maintenanceMarginFractionBPS: 50, // MMF = 0.5%
      maxProfitRateBPS: 90000, // 900%
      assetClass: commoditiesAssetClass,
      allowIncreasePosition: true,
      active: true,
      fundingRate: {
        maxSkewScaleUSD: ethers.utils.parseUnits("300000000", 30), // 300 M
        maxFundingRate: ethers.utils.parseUnits("0.00000116", 18), // 10% per day
      },
      maxLongPositionSize: ethers.utils.parseUnits("10000000", 30),
      maxShortPositionSize: ethers.utils.parseUnits("10000000", 30),
    })
  ).wait();
  console.log("> ConfigStorage: Add Market Config success!");
};
export default func;
func.tags = ["AddMarket-XAUUSD"];
