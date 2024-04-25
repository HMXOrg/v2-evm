import { EcoPythCalldataBuilder__factory } from "../../../typechain";
import { ethers } from "ethers";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  ecoPythAssetIdByIndex,
  ecoPythHoomanReadableByIndex,
  ecoPythPriceFeedIdsByIndex,
  multiplicationFactorMapByAssetId,
} from "../constants/eco-pyth-index";
import { loadConfig } from "./config";

function _priceToPriceE8(price: string, expo: number, multiplicationFactor: number) {
  const targetBN = ethers.BigNumber.from(8);
  const priceBN = ethers.BigNumber.from(price).mul(multiplicationFactor);
  const expoBN = ethers.BigNumber.from(expo);
  const priceDecimals = expoBN.mul(-1);
  if (targetBN.sub(priceDecimals).gte(0)) {
    return priceBN.mul(Math.pow(10, targetBN.sub(priceDecimals).toNumber()));
  }
  return priceBN.div(Math.pow(10, priceDecimals.sub(targetBN).toNumber()));
}

const assetIdWithPriceAdapters = ["GLP", "wstETH", "GM-BTCUSD", "GM-ETHUSD", "DIX"];

export async function getUpdatePriceData(
  priceIds: string[],
  provider: ethers.providers.Provider
): Promise<[Array<{ asset: string; price: string }>, number, string[], string[], string]> {
  let hashedVaas = "";

  const table = [];
  const chainId = (await provider.getNetwork()).chainId;
  const config = loadConfig(chainId);

  const MAX_PRICE_DIFF = 1500_00;
  const connection = new EvmPriceServiceConnection("https://hermes.pyth.network/", {
    logger: console,
  });

  const prices = await connection.getLatestPriceFeeds(
    priceIds.filter((each) => !assetIdWithPriceAdapters.includes(each))
  );
  if (!prices) {
    throw new Error("Failed to get prices from Pyth");
  }
  const buildData = [];
  for (let i = 0; i < priceIds.length; i++) {
    if (assetIdWithPriceAdapters.includes(priceIds[i])) {
      // If the asset is GLP, use the GLP price from the contract
      buildData.push({
        assetId: ecoPythAssetIdByIndex[i],
        priceE8: ethers.BigNumber.from(0), // EcoPythCallDataBuilder will use the GLP price from the contract
        publishTime: ethers.BigNumber.from(Math.floor(Date.now() / 1000)),
        maxDiffBps: MAX_PRICE_DIFF,
      });
      table.push({
        asset: ecoPythHoomanReadableByIndex[i],
        price: "Read from contract",
      });
      continue;
    }
    // If the asset is not GLP, use the price from Pyth
    const priceFeed = prices.find((each) => each.id === ecoPythPriceFeedIdsByIndex[i].substring(2));
    if (!priceFeed) {
      throw new Error(`Failed to get price feed from Pyth ${ecoPythPriceFeedIdsByIndex[i]}`);
    }
    const priceInfo = priceFeed.getPriceUnchecked();
    const multiplicationFactor = multiplicationFactorMapByAssetId.has(ecoPythAssetIdByIndex[i])
      ? multiplicationFactorMapByAssetId.get(ecoPythAssetIdByIndex[i])!
      : 1;
    buildData.push({
      assetId: ecoPythAssetIdByIndex[i],
      priceE8: _priceToPriceE8(priceInfo.price, priceInfo.expo, multiplicationFactor),
      publishTime: ethers.BigNumber.from(priceInfo.publishTime),
      maxDiffBps: MAX_PRICE_DIFF,
    });
    table.push({
      asset: ecoPythHoomanReadableByIndex[i],
      price: ethers.utils.formatUnits(_priceToPriceE8(priceInfo.price, priceInfo.expo, multiplicationFactor), 8),
    });
  }
  const vaas = await connection.getPriceFeedsUpdateData(
    priceIds.filter((each) => !assetIdWithPriceAdapters.includes(each))
  );
  hashedVaas = ethers.utils.keccak256(
    "0x" +
      vaas
        .map((each) => {
          return each.substring(2);
        })
        .join("")
  );
  const ecoPythCalldataBuilder = EcoPythCalldataBuilder__factory.connect(
    config.oracles.unsafeEcoPythCalldataBuilder3,
    provider
  );
  const [minPublishedTime, priceUpdateData, publishTimeDiffUpdateData] = await ecoPythCalldataBuilder.build(buildData);
  return [table, minPublishedTime.toNumber(), priceUpdateData, publishTimeDiffUpdateData, hashedVaas];
}

export function priceToClosestTick(price: number): number {
  const result = Math.log(price) / Math.log(1.0001);
  const closestUpperTick = Math.ceil(result);
  const closestLowerTick = Math.floor(result);

  const closetPriceUpper = Math.pow(1.0001, closestUpperTick);
  const closetPriceLower = Math.pow(1.0001, closestLowerTick);

  return Math.abs(price - closetPriceUpper) < Math.abs(price - closetPriceLower) ? closestUpperTick : closestLowerTick;
}
