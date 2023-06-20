import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ConfigStorage__factory, EcoPyth__factory, PythAdapter__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    config: {
      assetId: ethers.utils.formatBytes32String("ETH"),
      tokenAddress: config.tokens.weth,
      decimals: 18,
      isStableCoin: false,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    config: {
      assetId: ethers.utils.formatBytes32String("BTC"),
      tokenAddress: config.tokens.wbtc,
      decimals: 8,
      isStableCoin: false,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("DAI"),
    config: {
      assetId: ethers.utils.formatBytes32String("DAI"),
      tokenAddress: config.tokens.dai,
      decimals: 18,
      isStableCoin: true,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("USDC"),
    config: {
      assetId: ethers.utils.formatBytes32String("USDC"),
      tokenAddress: config.tokens.usdc,
      decimals: 6,
      isStableCoin: true,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("USDT"),
    config: {
      assetId: ethers.utils.formatBytes32String("USDT"),
      tokenAddress: config.tokens.usdt,
      decimals: 6,
      isStableCoin: true,
    },
  },
  {
    assetId: ethers.utils.formatBytes32String("GLP"),
    config: {
      assetId: ethers.utils.formatBytes32String("GLP"),
      tokenAddress: config.tokens.sglp,
      decimals: 18,
      isStableCoin: false,
    },
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Asset Configs...");
  await (
    await configStorage.setAssetConfigs(
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.config)
    )
  ).wait();
  console.log("> ConfigStorage: Set Asset Configs success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
