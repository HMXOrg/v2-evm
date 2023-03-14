import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { Calculator__factory, VaultStorage__factory } from "../typechain";
import { getConfig } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  console.log(deployer.address);

  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);
  const calculator = Calculator__factory.connect(config.calculator, deployer);
  console.log("traderBalances", await vaultStorage.traderBalances(deployer.address, config.tokens.usdc));
  console.log("Equity", await calculator.getEquity(deployer.address, 0, ethers.utils.defaultAbiCoder.encode([], [])));
};

export default func;
func.tags = ["ReadData"];
