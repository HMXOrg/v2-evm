import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("StakedGlpOracleAdapter", deployer);
  const contract = await Contract.deploy(
    config.tokens.sglp,
    config.yieldSources.gmx.glpManager,
    ethers.utils.formatBytes32String("GLP")
  );
  await contract.deployed();
  console.log(`Deploying StakedGlpOracleAdapter Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.oracles.sglpStakedAdapter = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "StakedGlpOracleAdapter",
  });
};

export default func;
func.tags = ["DeployStakedGlpOracleAdapter"];
