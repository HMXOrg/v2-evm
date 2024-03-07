import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const liquidationConfig = {
    liquidationFeeUSDE30: ethers.utils.parseUnits("5", 30),
  };

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const config = loadConfig(chainId);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/ConfigStorage] Set Liquidation Config...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setLiquidationConfig", [liquidationConfig])
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
