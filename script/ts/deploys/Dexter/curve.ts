import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("CurveDexter", [config.tokens.weth], deployer);

  await contract.deployed();
  console.log(`Deploying CurveDexter Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.extension.dexter.curve = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "CurveDexter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
