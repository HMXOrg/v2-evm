import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("EcoPyth", deployer);
  const contract = await Contract.deploy();
  await contract.deployed();
  console.log(`Deploying EcoPyth Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.oracle.ecoPyth = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "EcoPyth",
  });
};

export default func;
func.tags = ["DeployEcoPyth"];
