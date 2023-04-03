import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LimitTradeHandler", deployer);
  const contract = await Contract.deploy(config.tokens.weth, config.services.trade, config.oracle.leanPyth, 30);
  await contract.deployed();
  console.log(`Deploying LimitTradeHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.limitTrade = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "LimitTradeHandler",
  });
};

export default func;
func.tags = ["DeployLimitTradeHandler"];
