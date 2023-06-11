import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import { EcoPyth__factory } from "../../typechain";
import { getConfig } from "../utils/config";
import { getUpdatePriceData, getPricesFromPythWithPriceIds } from "../utils/price";

const wethPriceId = "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
const wbtcPriceId = "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
const usdcPriceId = "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a";
const usdtPriceId = "0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b";
const daiPriceId = "0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd";
const applePriceId = "0x49f6b65cb1de6b10eaf75e7c03ca029c306d0357e91b5311b175084a5ad55688";
const jpyPriceId = "0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52";
const glpPriceId = "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a"; // USDC override
const xauPriceId = "0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // https://xc-mainnet.pyth.network
  // https://xc-testnet.pyth.network
  const deployer = (await ethers.getSigners())[0];
  const connection = new EvmPriceServiceConnection("https://xc-testnet.pyth.network", {
    logger: console, // Providing logger will allow the connection to log its events.
  });

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

  const pyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);
  const blockTimestamp = Math.floor(new Date().valueOf() / 1000);

  const [priceUpdateData, publishTimeDiffUpdateData] = await getUpdatePriceData(
    deployer,
    priceUpdates,
    Array(priceUpdates.length).fill(0),
    true
  );

  await (await pyth.setUpdater(deployer.address, true)).wait();
  await (
    await pyth.updatePriceFeeds(
      priceUpdateData,
      publishTimeDiffUpdateData,
      blockTimestamp,
      ethers.utils.formatBytes32String("")
    )
  ).wait();
  console.log("> Feed Price success!");
};
export default func;
func.tags = ["FeedPriceEcoPyth"];
