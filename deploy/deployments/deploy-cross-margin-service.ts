import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("CrossMarginService", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.storages.config,
    config.storages.vault,
    config.storages.perp,
    config.calculator,
  ]);
  await contract.deployed();
  console.log(`Deploying CrossMarginService Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.services.crossMargin = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "CrossMarginService",
  });
};

export default func;
func.tags = ["DeployCrossMarginService"];
