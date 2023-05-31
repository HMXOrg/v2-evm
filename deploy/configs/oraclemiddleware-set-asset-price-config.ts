import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory, OracleMiddleware__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const wbtcAssetId = ethers.utils.formatBytes32String("BTC");
const usdcAssetId = ethers.utils.formatBytes32String("USDC");
const usdtAssetId = ethers.utils.formatBytes32String("USDT");
const daiAssetId = ethers.utils.formatBytes32String("DAI");
const appleAssetId = ethers.utils.formatBytes32String("AAPL");
const jpyAssetId = ethers.utils.formatBytes32String("JPY");
const glpAssetId = ethers.utils.formatBytes32String("GLP");

const assetConfigs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDC"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDT"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("DAI"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("AAPL"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("JPY"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
  {
    assetId: ethers.utils.formatBytes32String("GLP"),
    confidenceThreshold: 0,
    trustPriceAge: 60 * 60 * 24 * 365,
    adapter: config.oracles.pythAdapter,
  },
];
const assetId = ethers.utils.formatBytes32String("GLP");
const confidenceThreshold = 0; // UNUSED
const trustPriceAge = 15; // 15 seconds
const adapter = config.oracles.pythAdapter;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("> OracleMiddleware setAssetPriceConfig...");
  for (let i = 0; i < assetConfigs.length; i++) {
    const assetConfig = assetConfigs[i];
    await (
      await oracle.setAssetPriceConfig(
        assetConfig.assetId,
        assetConfig.confidenceThreshold,
        assetConfig.trustPriceAge,
        assetConfig.adapter
      )
    ).wait();
  }
  console.log("> OracleMiddleware setAssetPriceConfig success!");
};
export default func;
func.tags = ["OracleMiddlewareSetAssetPriceConfig"];
