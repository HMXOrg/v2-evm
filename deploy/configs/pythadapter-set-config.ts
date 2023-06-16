import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const ethAssetId = ethers.utils.formatBytes32String("ETH");
const wbtcAssetId = ethers.utils.formatBytes32String("BTC");
const usdcAssetId = ethers.utils.formatBytes32String("USDC");
const usdtAssetId = ethers.utils.formatBytes32String("USDT");
const daiAssetId = ethers.utils.formatBytes32String("DAI");
const appleAssetId = ethers.utils.formatBytes32String("AAPL");
const jpyAssetId = ethers.utils.formatBytes32String("JPY");
const glpAssetId = ethers.utils.formatBytes32String("GLP");
const xauAssetId = ethers.utils.formatBytes32String("XAU");

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("> PythAdapter Set Config...");
  await (await pythAdapter.setConfig(glpAssetId, glpAssetId, false)).wait();
  console.log("> PythAdapter Set Config success!");
};
export default func;
func.tags = ["PythAdapterSetConfig"];
