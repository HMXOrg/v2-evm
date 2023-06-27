import { ethers } from "hardhat";
import { EcoPyth__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

async function main() {
  // https://xc-mainnet.pyth.network
  // https://xc-testnet.pyth.network
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const pyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);
  const assetIds = await pyth.getAssetIds();
  console.log(assetIds);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
