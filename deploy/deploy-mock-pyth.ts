import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("MockPyth", deployer);
  const contract = await Contract.deploy(1000, 0);
  await contract.deployed();
  console.log(`Deploying MockPyth Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.oracle.ecoPyth = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "MockPyth",
  });
};

export default func;
func.tags = ["DeployMockPyth"];
