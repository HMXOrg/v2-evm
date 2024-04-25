import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { CollateralReader__factory } from "../../../../typechain";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const CollateralReader = new CollateralReader__factory(deployer);
  const collateralReader = await CollateralReader.deploy(config.storages.vault, config.storages.config);

  await collateralReader.deployed();
  console.log(`[deploys/CollateralReader] Deploying CollateralReader Contract`);
  console.log(`[deploys/CollateralReader] Deployed at: ${collateralReader.address}`);

  config.reader.collateral = collateralReader.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: collateralReader.address,
    name: "CollateralReader",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
