import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const liquidityConfig = {
  depositFeeRateBPS: 0, // 0%
  withdrawFeeRateBPS: 30, // 0.3%
  maxHLPUtilizationBPS: 8000, // 80%
  hlpTotalTokenWeight: 0, // DEFAULT
  hlpSafetyBufferBPS: 2000, // 20%
  taxFeeRateBPS: 50, // 0.5%
  flashLoanFeeRateBPS: 0,
  dynamicFeeEnabled: true,
  enabled: true,
};

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Liquidity Config...");
  await (await configStorage.setLiquidityConfig(liquidityConfig)).wait();
  console.log("> ConfigStorage: Set Liquidity Config success!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
