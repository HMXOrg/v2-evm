import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory, OracleMiddleware__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const assetConfigs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 5, // 5 minutes
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 5, // 5 minutes
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDC"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 5, // 5 minutes
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDT"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 5, // 5 minutes
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("DAI"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 5, // 5 minutes
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("AAPL"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("JPY"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("GLP"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 5, // 5 minutes
    adapter: config.oracles.sglpStakedAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAU"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("AMZN"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("NVDA"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("MSFT"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("TSLA"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("EUR"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAG"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 3, // 3 days
    adapter: config.oracles.pythAdapter,
  },
];

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("> OracleMiddleware setAssetPriceConfigs...");
  await (
    await oracle.setAssetPriceConfigs(
      assetConfigs.map((each) => each.assetId),
      assetConfigs.map((each) => each.confidenceThreshold),
      assetConfigs.map((each) => each.trustPriceAge),
      assetConfigs.map((each) => each.adapter)
    )
  ).wait();
  console.log("> OracleMiddleware setAssetPriceConfigs success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
