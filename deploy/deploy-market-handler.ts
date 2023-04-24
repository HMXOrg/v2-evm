import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("MarketTradeHandler", deployer);
  const contract = await Contract.deploy(config.services.trade, config.oracles.ecoPyth);
  await contract.deployed();
  console.log(`Deploying MarketTradeHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.marketTrade = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "MarketTradeHandler",
  });
};

export default func;
func.tags = ["DeployMarketTradeHandler"];
