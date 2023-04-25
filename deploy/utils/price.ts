import { EcoPyth__factory } from "../../typechain";
import { getConfig } from "./config";
import { ethers } from "hardhat";

export async function getUpdatePriceData(
  priceUpdates: number[],
  publishTimeDiff: number[]
): Promise<[string[], string[]]> {
  const config = getConfig();
  const pyth = EcoPyth__factory.connect(config.oracles.ecoPyth, ethers.getDefaultProvider());
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
