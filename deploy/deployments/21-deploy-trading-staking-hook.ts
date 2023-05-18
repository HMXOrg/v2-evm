import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const tradingStaking = "0x934dD689e9962427aab71b226b386945F5d190bC";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("TradingStakingHook", deployer);

  const contract = await upgrades.deployProxy(Contract, [tradingStaking, config.services.trade]);
  await contract.deployed();
  console.log(`Deploying TradingStakingHook Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.hooks.tradingStaking = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "TradingStakingHook",
  });
};

export default func;
func.tags = ["DeployTradingStakingHook"];
