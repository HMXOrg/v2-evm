import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const BPS = 10000;
const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    collateralConfig: {
      collateralFactorBPS: 0.85 * BPS,
      accepted: true,
      settleStrategy: ethers.constants.AddressZero,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    collateralConfig: {
      collateralFactorBPS: 0.85 * BPS,
      accepted: true,
      settleStrategy: ethers.constants.AddressZero,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("DAI"),
    collateralConfig: {
      collateralFactorBPS: 1 * BPS,
      accepted: true,
      settleStrategy: ethers.constants.AddressZero,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("USDC"),
    collateralConfig: {
      collateralFactorBPS: 1 * BPS,
      accepted: true,
      settleStrategy: ethers.constants.AddressZero,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("USDT"),
    collateralConfig: {
      collateralFactorBPS: 1 * BPS,
      accepted: true,
      settleStrategy: ethers.constants.AddressZero,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("GLP"),
    collateralConfig: {
      collateralFactorBPS: 0.8 * BPS,
      accepted: true,
      settleStrategy: ethers.constants.AddressZero,
    },
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Collateral Configs...");
  await (
    await configStorage.setCollateralTokenConfigs(
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.collateralConfig)
    )
  ).wait();
  console.log("> ConfigStorage: Set Collateral Configs success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
