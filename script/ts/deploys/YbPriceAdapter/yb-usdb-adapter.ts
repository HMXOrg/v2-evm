import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const ybToken = config.tokens.ybusdb!;
  const assetId = ethers.utils.formatBytes32String("DAI");
  const contract = await ethers.deployContract("YbPriceAdapter", [ybToken, assetId], deployer);

  await contract.deployed();
  console.log(`[deploys/YbPriceAdapter] Deploying YbPriceAdapter for ybUSDB Contract`);
  console.log(`[deploys/YbPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.ybusdb = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
    constructorArguments: [ybToken, assetId],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
