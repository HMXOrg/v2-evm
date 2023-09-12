import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract(
    "GlpPriceAdapter",
    [config.tokens.sglp, config.vendors.gmx.glpManager],
    deployer
  );

  await contract.deployed();
  console.log(`[deploys/GlpPriceAdapter] Deploying GlpPriceAdapter Contract`);
  console.log(`[deploys/GlpPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.glp = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "GlpPriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
