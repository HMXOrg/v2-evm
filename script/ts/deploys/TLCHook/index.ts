import { ethers, run, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const tradeService = config.services.trade;
const tlc = config.tokens.traderLoyaltyCredit;
const tlcStaking = config.staking.tlc;

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("TLCHook", deployer);

  console.log(`[delpoys/TLCHook] Deploying TLCHook Contract`);
  const contract = await upgrades.deployProxy(Contract, [tradeService, tlc, tlcStaking]);
  await contract.deployed();
  console.log(`[deploys/TLCHook] Deployed at: ${contract.address}`);

  config.hooks.tlc = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: await getImplementationAddress(network.provider, contract.address),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
