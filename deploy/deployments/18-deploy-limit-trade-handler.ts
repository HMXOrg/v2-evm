import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const minExecutionFee = 30; // 30 wei
const minExecutionTimestamp = 60 * 60 * 5; // 5 minutes

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LimitTradeHandler", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.tokens.weth,
    config.services.trade,
    config.oracles.ecoPyth,
    minExecutionFee,
    minExecutionTimestamp,
  ]);
  await contract.deployed();
  console.log(`Deploying LimitTradeHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.limitTrade = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "LimitTradeHandler",
  });
};

export default func;
func.tags = ["DeployLimitTradeHandler"];
