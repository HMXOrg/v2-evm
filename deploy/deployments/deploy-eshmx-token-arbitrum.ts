import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("EsHMX", deployer);
  const contract = await Contract.deploy(true);
  await contract.deployed();
  console.log(`Deploying EsHMX Contract on Arbitrum`);
  console.log(`Deployed at: ${contract.address}`);

  config.tokens.esHmx = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "EsHMX",
  });
};

export default func;
func.tags = ["DeployEsHMXArbitrum"];
