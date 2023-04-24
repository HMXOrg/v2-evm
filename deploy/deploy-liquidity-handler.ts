import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LiquidityHandler", deployer);
  const contract = await Contract.deploy(config.services.liquidity, config.oracle.ecoPyth, 30);
  await contract.deployed();
  console.log(`Deploying LiquidityHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.liquidity = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "LiquidityHandler",
  });
};

export default func;
func.tags = ["DeployLiquidityHandler"];
