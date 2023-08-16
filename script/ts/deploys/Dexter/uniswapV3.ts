import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract(
    "UniswapDexter",
    [config.vendors.uniswap.permit2, config.vendors.uniswap.universalRouter],
    deployer
  );

  await contract.deployed();
  console.log(`Deploying UniswapDexter Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.extension.dexter.uniswapV3 = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "UniswapDexter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
