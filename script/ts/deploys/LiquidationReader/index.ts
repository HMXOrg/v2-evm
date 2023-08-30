import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("LiquidationReader", deployer);
  const contract = await Contract.deploy(
    "0x58120a4f1959D1670e84BBBc1C403e08cD152bae",
    "0xCd6a5d5D7028D3EF48e25B626180b256EF901C4a"
    // config.storages.perp,
    // config.calculator
  );

  await contract.deployed();
  console.log(`Deploying LiquidationReader Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.reader.liquidation = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "LiquidationReader",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
