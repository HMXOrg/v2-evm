import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory, OracleMiddleware__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const BigNumber = ethers.BigNumber;
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
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);
  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);
  console.log([
    ethAssetId,
    wbtcAssetId,
    usdcAssetId,
    usdtAssetId,
    daiAssetId,
    appleAssetId,
    jpyAssetId,
    glpAssetId,
    xauAssetId,
  ]);
  console.log(await ecoPyth.getAssetIds());
  console.log((await ecoPyth.getPriceUnsafe(ethAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(wbtcAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(usdcAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(usdtAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(daiAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(appleAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(jpyAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(glpAssetId)).price);
  console.log((await ecoPyth.getPriceUnsafe(xauAssetId)).price);
};

export default func;
func.tags = ["ReadPrice"];
