import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory } from "../../typechain";
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
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);

  console.log("> EcoPyth Insert Asset Id...");
  await (await ecoPyth.setAssetId(1, ethAssetId)).wait();
  // await (await ecoPyth.setAssetId(wbtcAssetId)).wait();
  // await (await ecoPyth.setAssetId(usdcAssetId)).wait();
  // await (await ecoPyth.setAssetId(usdtAssetId)).wait();
  // await (await ecoPyth.setAssetId(daiAssetId)).wait();
  // await (await ecoPyth.setAssetId(appleAssetId)).wait();
  // await (await ecoPyth.setAssetId(jpyAssetId)).wait();
  // await (await ecoPyth.setAssetId(glpAssetId)).wait();
  // await (await ecoPyth.setAssetId(jpyAssetId)).wait();
  // await (await ecoPyth.setAssetId(xauAssetId)).wait();
  console.log("> EcoPyth Insert Asset Id!");
};
export default func;
func.tags = ["EcoPythInsertAssetId"];
