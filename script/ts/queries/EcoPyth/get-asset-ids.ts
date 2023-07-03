import { ethers } from "hardhat";
import { getConfig } from "../../utils/config";
import { EcoPyth__factory } from "../../../../typechain";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);

  console.log(await ecoPyth.getAssetIds());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
