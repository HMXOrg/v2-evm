import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory, OracleMiddleware__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const assetId = ethers.utils.formatBytes32String("GLP");
const confidenceThreshold = 0; // UNUSED
const trustPriceAge = 15; // 15 seconds
const adapter = config.oracles.pythAdapter;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("> OracleMiddleware setAssetPriceConfig...");
  await (await oracle.setAssetPriceConfig(assetId, confidenceThreshold, trustPriceAge, adapter)).wait();
  console.log("> OracleMiddleware setAssetPriceConfig success!");
};
export default func;
func.tags = ["OracleMiddlewareSetAssetPriceConfig"];
