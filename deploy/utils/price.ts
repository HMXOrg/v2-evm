import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { EcoPyth__factory } from "../../typechain";
import { getConfig } from "./config";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";

const wethPriceId = "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
const wbtcPriceId = "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
const usdcPriceId = "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a";
const usdtPriceId = "0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b";
const daiPriceId = "0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd";
const applePriceId = "0x49f6b65cb1de6b10eaf75e7c03ca029c306d0357e91b5311b175084a5ad55688";
const jpyPriceId = "0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52";

export async function getPricesFromPyth(): Promise<number[]> {
  const connection = new EvmPriceServiceConnection("https://xc-mainnet.pyth.network", {
    logger: console,
  });

  const prices = await connection.getLatestPriceFeeds([
    wethPriceId,
    wbtcPriceId,
    usdcPriceId,
    usdtPriceId,
    daiPriceId,
    applePriceId,
    jpyPriceId,
  ]);
  return prices!.map((each) => {
    const rawPrice = Number(each.getPriceUnchecked().price);
    const expo = Number(each.getPriceUnchecked().expo);
    return Number((rawPrice * Math.pow(10, expo)).toFixed(8));
  });
}

export async function getUpdatePriceData(
  signer: SignerWithAddress,
  priceUpdates: number[],
  publishTimeDiff: number[],
  useRealPrices: boolean
): Promise<[string[], string[]]> {
  if (useRealPrices) {
    // https://xc-mainnet.pyth.network
    // https://xc-testnet.pyth.network
    const connection = new EvmPriceServiceConnection("https://xc-mainnet.pyth.network", {
      logger: console,
    });

    const prices = await connection.getLatestPriceFeeds([
      wethPriceId,
      wbtcPriceId,
      usdcPriceId,
      usdtPriceId,
      daiPriceId,
      applePriceId,
      jpyPriceId,
    ]);
    priceUpdates = prices!.map((each) => {
      const rawPrice = Number(each.getPriceUnchecked().price);
      const expo = Number(each.getPriceUnchecked().expo);
      return Number((rawPrice * Math.pow(10, expo)).toFixed(8));
    });
    console.log("priceUpdates", priceUpdates);
  }

  const config = getConfig();
  const pyth = EcoPyth__factory.connect(config.oracles.ecoPyth, signer);
  const tickPrices = priceUpdates.map((each) => priceToClosestTick(each));
  const priceUpdateData = await pyth.buildPriceUpdateData(tickPrices);
  const publishTimeDiffUpdateData = await pyth.buildPublishTimeUpdateData(publishTimeDiff);
  return [priceUpdateData, publishTimeDiffUpdateData];
}

export function priceToClosestTick(price: number): number {
  const result = Math.log(price) / Math.log(1.0001);
  const closestUpperTick = Math.ceil(result);
  const closestLowerTick = Math.floor(result);

  const closetPriceUpper = Math.pow(1.0001, closestUpperTick);
  const closetPriceLower = Math.pow(1.0001, closestLowerTick);

  return Math.abs(price - closetPriceUpper) < Math.abs(price - closetPriceLower) ? closestUpperTick : closestLowerTick;
}
