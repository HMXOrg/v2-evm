import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const OracleMiddleware = await ethers.getContractFactory("OracleMiddleware", deployer);
  const oracleMiddleware = await OracleMiddleware.deploy();
  await oracleMiddleware.deployed();
  console.log(`Deploying OracleMiddleware Contract`);
  console.log(`Deployed at: ${oracleMiddleware.address}`);

  config.oracles.middleware = oracleMiddleware.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: oracleMiddleware.address,
    name: "OracleMiddleware",
  });
};

export default func;
func.tags = ["DeployOracleMiddleware"];
