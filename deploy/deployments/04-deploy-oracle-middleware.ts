import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const OracleMiddleware = await ethers.getContractFactory("OracleMiddleware", deployer);
  const contract = await upgrades.deployProxy(OracleMiddleware, []);
  await contract.deployed();
  console.log(`Deploying OracleMiddleware Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.oracles.middleware = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "OracleMiddleware",
  });
};

export default func;
func.tags = ["DeployOracleMiddleware"];
