import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Liquidity Config...");
  await (
    await configStorage.setLiquidityConfig({
      depositFeeRateBPS: 30, // 0.3%
      withdrawFeeRateBPS: 30, // 0.3%
      maxPLPUtilizationBPS: 8000, // 80%
      plpTotalTokenWeight: 0,
      plpSafetyBufferBPS: 2000, // 20%
      taxFeeRateBPS: 50, // 0.5%
      flashLoanFeeRateBPS: 0,
      dynamicFeeEnabled: true,
      enabled: true,
    })
  ).wait();
  console.log("> ConfigStorage: Set Liquidity Config success!");
};
export default func;
func.tags = ["SetLiquidityConfig"];
