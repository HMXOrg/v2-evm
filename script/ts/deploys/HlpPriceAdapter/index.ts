import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("HlpPriceAdapter", [config.tokens.hlp, config.calculator], deployer);

  await contract.deployed();
  console.log(`[deploys/HlpPriceAdapter] Deploying HlpPriceAdapter Contract`);
  console.log(`[deploys/HlpPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.hlp = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "HlpPriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
