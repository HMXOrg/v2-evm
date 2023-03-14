import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { Calculator__factory, OracleMiddleware__factory, VaultStorage__factory } from "../typechain";
import { getConfig } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();
const subAccountId = 1;

const usdcAssetId = '0x0000000000000000000000000000000000000000000000000000000000000003';


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const address = BigNumber.from(deployer.address).xor(subAccountId).toHexString()

  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);
  const calculator = Calculator__factory.connect(config.calculator, deployer);
  const oracle = OracleMiddleware__factory.connect(config.oracle.middleware, deployer)

  const traderBalances = await vaultStorage.traderBalances(address, config.tokens.usdc)
  const freeCollateral = await calculator.getFreeCollateral(address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000")
  const equity = await calculator.getEquity(address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000")
  const usdcPrice = (await oracle.getLatestPrice(usdcAssetId, false))._price;

  console.log("traderBalances", ethers.utils.formatUnits(traderBalances, 6));
  console.log("equity", ethers.utils.formatUnits(equity, 30));
  console.log("freeCollateral", ethers.utils.formatUnits(freeCollateral, 30));
  console.log("usdcPrice", ethers.utils.formatUnits(usdcPrice, 30));
};

export default func;
func.tags = ["ReadData"];
