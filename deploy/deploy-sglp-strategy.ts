import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const keeper = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
const treasury = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
const strategyBPS = 1000; // 10%

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("StakedGlpStrategy", deployer);
  const contract = await Contract.deploy(
    config.tokens.sglp,
    config.yieldSources.gmx.rewardRouterV2,
    config.yieldSources.gmx.rewardTracker,
    config.yieldSources.gmx.glpManager,
    config.oracles.middleware,
    config.storages.vault,
    keeper,
    treasury,
    strategyBPS
  );
  await contract.deployed();
  console.log(`Deploying StakedGlpStrategy Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.oracles.sglpStakedAdapter = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "StakedGlpStrategy",
  });
};

export default func;
func.tags = ["DeployStakedGlpStrategy"];
