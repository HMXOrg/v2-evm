import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

const config = getConfig();

const assetClassName = "COMMODITY";
const assetConfig = {
  baseBorrowingRate: 27777777777, // 0.01% per hour
};

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log(`[configs/ConfigStorage] Add ${assetClassName} to asset class config...`);
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("addAssetClassConfig", [assetConfig])
  );
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
