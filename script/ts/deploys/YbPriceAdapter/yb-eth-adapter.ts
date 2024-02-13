import { ethers, run } from "hardhat";
import { writeConfigFile } from "../../utils/config";
import BlastSepoliaConfig from "../../../../configs/blast.sepolia.json";

const config = BlastSepoliaConfig;

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const ybToken = config.tokens.ybeth;
  const assetId = ethers.utils.formatBytes32String("ybETH");
  const contract = await ethers.deployContract("YbPriceAdapter", [ybToken, assetId], deployer);

  await contract.deployed();
  console.log(`[deploys/YbPriceAdapter] Deploying YbPriceAdapter Contract`);
  console.log(`[deploys/YbPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.ybeth = contract.address;
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
