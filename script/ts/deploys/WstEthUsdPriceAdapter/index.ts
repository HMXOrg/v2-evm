import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract(
    "WstEthUsdPriceAdapter",
    [config.vendors.chainlink.wstEthEthPriceFeed, config.vendors.chainlink.ethUsdPriceFeed],
    deployer
  );

  await contract.deployed();
  console.log(`[deploys/WstEthUsdPriceAdapter] Deploying WstEthUsdPriceAdapter Contract`);
  console.log(`[deploys/WstEthUsdPriceAdapter] Deployed at: ${contract.address}`);

  config.oracles.priceAdapters.wstEth = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "WstEthUsdPriceAdapter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
