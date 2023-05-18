import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const tradeService = config.services.trade;
const tlc = "0x962972C4DA1c0398296fCb6Ee04eea3A4f48b0Bb";
const tlcStaking = "0x8DdF31A4C859cA0a26a7b9B361218FB3c50A30a5";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("TLCHook", deployer);

  const contract = await upgrades.deployProxy(Contract, [tradeService, tlc, tlcStaking]);
  await contract.deployed();
  console.log(`Deploying TLCHook Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.hooks.tlc = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "TLCHook",
  });
};

export default func;
func.tags = ["DeployTLCHook"];
