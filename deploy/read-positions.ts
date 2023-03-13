import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { PerpStorage__factory } from "../typechain";
import { getConfig } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const perpStorage = PerpStorage__factory.connect(config.storages.perp, deployer);
  const positions = await perpStorage.getPositionBySubAccount(deployer.address);
  console.log(positions);
};

export default func;
func.tags = ["ReadPositions"];
