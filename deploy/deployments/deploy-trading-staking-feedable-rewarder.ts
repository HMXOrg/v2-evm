import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const name = "JPYUSD";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("FeedableRewarder", deployer);
  const contract = await upgrades.deployProxy(Contract, [name, config.tokens.esHmx, config.staking.trading]);
  await contract.deployed();
  console.log(`Deploying FeedableRewarder Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.rewarders.tradingStaking[name] = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "FeedableRewarder",
  });
};

export default func;
func.tags = ["DeployTradingStakingFeedableRewarder"];
