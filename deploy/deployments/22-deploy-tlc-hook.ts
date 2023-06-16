import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const tradeService = config.services.trade;
const tlc = "0xe8Ae03C982330d1Ef8a912697654633708c7905a";
const tlcStaking = "0x1b55dE2Fdd705264027A3FE143d933A00E10a729";

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
