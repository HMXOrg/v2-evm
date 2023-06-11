import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Liquidation Config...");
  await (
    await configStorage.setLiquidationConfig({
      liquidationFeeUSDE30: ethers.utils.parseUnits("5", 30),
    })
  ).wait();
  console.log("> ConfigStorage: Set Liquidation Config success!");
};
export default func;
func.tags = ["SetLiquidationConfig"];
