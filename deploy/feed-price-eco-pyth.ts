import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import { EcoPyth__factory } from "../typechain";
import { getConfig } from "./utils/config";

const wethPriceId = "0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6";
const wbtcPriceId = "0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b";
const usdcPriceId = "0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722";
const usdtPriceId = "0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588";
const daiPriceId = "0x87a67534df591d2dd5ec577ab3c75668a8e3d35e92e27bf29d9e2e52df8de412";
const applePriceId = "0xafcc9a5bb5eefd55e12b6f0b4c8e6bccf72b785134ee232a5d175afd082e8832";
const jpyPriceId = "0x20a938f54b68f1f2ef18ea0328f6dd0747f8ea11486d22b021e83a900be89776";

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
  ];

  const pyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);
  const tickPrices = priceUpdates.map((each) => priceToClosestTick(each));
  const priceUpdateData = await pyth.buildPriceUpdateData(tickPrices);
  const publishTimeDiffUpdateData = await pyth.buildPublishTimeUpdateData(Array(tickPrices.length).fill(0));
  const blockTimestamp = Math.floor(new Date().valueOf() / 1000);

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

function priceToClosestTick(price: number): number {
  const result = Math.log(price) / Math.log(1.0001);
  const closestUpperTick = Math.ceil(result);
  const closestLowerTick = Math.floor(result);

  const closetPriceUpper = Math.pow(1.0001, closestUpperTick);
  const closetPriceLower = Math.pow(1.0001, closestLowerTick);

  return Math.abs(price - closetPriceUpper) < Math.abs(price - closetPriceLower) ? closestUpperTick : closestLowerTick;
}
