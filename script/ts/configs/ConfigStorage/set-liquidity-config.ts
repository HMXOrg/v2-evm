import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

const config = getConfig();

const liquidityConfig = {
  depositFeeRateBPS: 0, // 0%
  withdrawFeeRateBPS: 30, // 0.3%
  maxHLPUtilizationBPS: 8000, // 80%
  hlpTotalTokenWeight: 0, // DEFAULT
  hlpSafetyBufferBPS: 2000, // 20%
  taxFeeRateBPS: 0, // 0.5%
  flashLoanFeeRateBPS: 0,
  dynamicFeeEnabled: true,
  enabled: true,
};

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/ConfigStorage] Set Liquidity Config...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setLiquidityConfig", [liquidityConfig])
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
