import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  ConfigStorage__factory,
  CrossMarginHandler__factory,
  ERC20__factory,
  LiquidityHandler__factory,
} from "../../typechain";
import { getConfig } from "../utils/config";
import { getPriceData } from "../utils/pyth";
import { getUpdatePriceData } from "../utils/price";

const BigNumber = ethers.BigNumber;
const config = getConfig();
const priceUpdates = [
  1900.02, // ETH
  20000.29, // ETH
  1, // USDC
  1, // USDT
  1, // DAI
  137.3, // AAPL
  198.2, // JPY
  1, // GLP
  1958, // XAU
];
const minPublishTime = Math.floor(new Date().valueOf() / 1000);
const publishTimeDiff = [
  0, // ETH
  0, // ETH
  0, // USDC
  0, // USDT
  0, // DAI
  0, // AAPL
  0, // JPY
  0, // GLP
  0, // XAU
];

const priceIds = [
  "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace", // ETH
  "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43", // BTC
  "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a", // USDC
  "0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b", // USDT
  "0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd", // DAI
  "0x49f6b65cb1de6b10eaf75e7c03ca029c306d0357e91b5311b175084a5ad55688", // AAPL
  "0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52", // JPY
  "0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2", // XAU
  "0xb5d0e0fa58a1f8b81498ae670ce93c872d14434b72c364885d4fa1b257cbb07a", // AMZN
  "0xd0ca23c1cc005e004ccf1db5bf76aeb6a49218f43dac3d4b275e92de12ded4d1", // MSFT
  "0x16dad506d7db8da01c87581c87ca897a012a153557d4d578c3b9c9e1bc0632f1", // TSLA
  "0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b", // EUR
  "0xf2fb02c32b055c805e7238d628e5e9dadef274376114eb1f012337cabe93871e", // XAG
];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const liquidityHandler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const [priceUpdateData, publishTimeDiffUpdateData] = await getUpdatePriceData(
    deployer,
    priceUpdates,
    publishTimeDiff,
    true,
    priceIds
  );
  console.log(`Execute Liquidity Order...`);
  await (
    await liquidityHandler.executeOrder(
      ethers.constants.MaxUint256,
      deployer.address,
      priceUpdateData,
      publishTimeDiffUpdateData,
      minPublishTime,
      ethers.utils.formatBytes32String(""),
      {
        gasLimit: 200000000,
      }
    )
  ).wait();
  console.log("Execute Liquidity Order Success!");
};

export default func;
func.tags = ["ExecuteLiquidityOrder"];
