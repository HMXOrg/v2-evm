import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("Calculator", deployer);
  const newImplementation = await upgrades.prepareUpgrade(config.calculator, Contract);

  await tenderly.verify({
    address: newImplementation.toString(),
    name: "Calculator",
  });
};

export default func;
func.tags = ["UpgradeCalculator"];
