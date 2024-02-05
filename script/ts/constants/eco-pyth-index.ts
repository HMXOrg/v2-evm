import { ethers } from "ethers";

// DO NOT CHANGE THE ORDER OF THE INDEXES
export const ecoPythPriceFeedIdsByIndex = [
  "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace", // ETHUSD
  "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43", // BTCUSD
  "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a", // USDCUSD
  "0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b", // USDTUSD
];
export const ecoPythAssetIdByIndex = [
  ethers.utils.formatBytes32String("ETH"),
  ethers.utils.formatBytes32String("BTC"),
  ethers.utils.formatBytes32String("USDC"),
  ethers.utils.formatBytes32String("USDT"),
];
export const ecoPythHoomanReadableByIndex = ["ETH", "BTC", "USDC", "USDT"];
export const multiplicationFactorMapByAssetId: Map<string, number> = new Map([
  [ethers.utils.formatBytes32String("1000SHIB"), 1000],
  [ethers.utils.formatBytes32String("1000PEPE"), 1000],
]);
