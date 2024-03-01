import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);

  const minimumPositionSize = ethers.utils.parseUnits("10", 30); // 10 USD

  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/ConfigStorage] Set Minimum Position Size...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setMinimumPositionSize", [minimumPositionSize])
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
