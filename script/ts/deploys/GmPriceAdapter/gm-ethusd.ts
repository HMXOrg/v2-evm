import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract(
    "GmPriceAdapter",
    [
      config.vendors.gmxV2.reader,
      config.vendors.gmxV2.dataStore,
      config.tokens.gmETHUSD,
      config.tokens.weth,
      8,
      config.tokens.weth,
      8,
      config.tokens.usdcCircle,
      6,
      0,
      0,
      2,
    ],
    deployer
  );

  await contract.deployed();
  console.log(`[deploys/GmPriceAdapter] Deploying GmPriceAdapter for GM-ETHUSD Contract`);
  console.log(`[deploys/GmPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.gmETHUSD = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "GmPriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
