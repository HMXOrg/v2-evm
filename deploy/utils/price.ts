import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { EcoPythCalldataBuilder__factory, EcoPyth__factory } from "../../typechain";
import { getConfig } from "./config";
import { ethers, network } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  ecoPythAssetIdByIndex,
  ecoPythHoomanReadableByIndex,
  ecoPythPriceFeedIdsByIndex,
} from "../../script/ts/constants/eco-pyth-index";

const wethPriceId = "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
const wbtcPriceId = "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
const usdcPriceId = "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a";
const usdtPriceId = "0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b";
const daiPriceId = "0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd";
const applePriceId = "0x49f6b65cb1de6b10eaf75e7c03ca029c306d0357e91b5311b175084a5ad55688";
const jpyPriceId = "0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52";
const glpPriceId = "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a"; // USDC override
const xauPriceId = "0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2";

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

function _priceToPriceE8(price: string, expo: number) {
  const targetBN = ethers.BigNumber.from(8);
  const priceBN = ethers.BigNumber.from(price);
  const expoBN = ethers.BigNumber.from(expo);
  const priceDecimals = expoBN.mul(-1);
  if (targetBN.sub(priceDecimals).gte(0)) {
    return priceBN.mul(Math.pow(10, targetBN.sub(priceDecimals).toNumber()));
  }
  return priceBN.div(Math.pow(10, priceDecimals.sub(targetBN).toNumber()));
}

export async function getUpdatePriceData(priceIds: string[]): Promise<[number, string[], string[], string]> {
  let hashedVaas = "";

  const MAX_PRICE_DIFF = 150_00;
  // https://xc-mainnet.pyth.network
  // https://xc-testnet.pyth.network
  const connection = new EvmPriceServiceConnection("https://xc-mainnet.pyth.network", {
    logger: console,
  });

  const prices = await connection.getLatestPriceFeeds(priceIds.filter((each) => each !== "GLP"));
  if (!prices) {
    throw new Error("Failed to get prices from Pyth");
  }
  const buildData = [];
  for (let i = 0; i < priceIds.length; i++) {
    if (priceIds[i] === "GLP") {
      // If the asset is GLP, use the GLP price from the contract
      buildData.push({
        assetId: ecoPythAssetIdByIndex[i],
        priceE8: ethers.BigNumber.from(0), // EcoPythCallDataBuilder will use the GLP price from the contract
        publishTime: ethers.BigNumber.from(Math.floor(Date.now() / 1000)),
        maxDiffBps: MAX_PRICE_DIFF,
      });
      continue;
    }
    // If the asset is not GLP, use the price from Pyth
    const priceFeed = prices.find((each) => each.id === ecoPythPriceFeedIdsByIndex[i].substring(2));
    if (!priceFeed) {
      throw new Error(`Failed to get price feed from Pyth ${ecoPythPriceFeedIdsByIndex[i]}`);
    }
    const priceInfo = priceFeed.getPriceUnchecked();
    buildData.push({
      assetId: ecoPythAssetIdByIndex[i],
      priceE8: _priceToPriceE8(priceInfo.price, priceInfo.expo),
      publishTime: ethers.BigNumber.from(priceInfo.publishTime),
      maxDiffBps: MAX_PRICE_DIFF,
    });
  }
  console.log(buildData);
  const vaas = await connection.getPriceFeedsUpdateData(priceIds.filter((each) => each !== "GLP"));
  hashedVaas = ethers.utils.keccak256(
    "0x" +
      vaas
        .map((each) => {
          return each.substring(2);
        })
        .join("")
  );

  const ecoPythCalldataBuilder = EcoPythCalldataBuilder__factory.connect(
    "0x44E31321E748dDc768a019aee4c62c14E53424F1",
    ethers.provider
  );
  const [minPublishedTime, priceUpdateData, publishTimeDiffUpdateData] = await ecoPythCalldataBuilder.build(buildData);
  return [minPublishedTime.toNumber(), priceUpdateData, publishTimeDiffUpdateData, hashedVaas];
}

export function priceToClosestTick(price: number): number {
  const result = Math.log(price) / Math.log(1.0001);
  const closestUpperTick = Math.ceil(result);
  const closestLowerTick = Math.floor(result);

  const closetPriceUpper = Math.pow(1.0001, closestUpperTick);
  const closetPriceLower = Math.pow(1.0001, closestLowerTick);

  return Math.abs(price - closetPriceUpper) < Math.abs(price - closetPriceLower) ? closestUpperTick : closestLowerTick;
}
