import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { getConfig, loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const pnlCollateralFactor = 0.8 * 10000; // 0.8 Collateral Factor for Unrealized PnL

  const deployer = (await ethers.getSigners())[0];
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/ConfigStorage] Set PnL Factor...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setPnlFactor", [pnlCollateralFactor])
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
