import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { ethers } from "ethers";

async function main(chainId: number) {
  const deployer = signers.deployer(chainId);
  const config = loadConfig(chainId);

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);

  console.log(await ecoPyth.getAssetIds());
  // console.log(ethers.utils.formatBytes32String("ICP"));
  // console.log([
  //   "0x4554480000000000000000000000000000000000000000000000000000000000", // ETH
  //   "0x4254430000000000000000000000000000000000000000000000000000000000", // BTC
  //   "0x5553444300000000000000000000000000000000000000000000000000000000", // USDC
  //   "0x5553445400000000000000000000000000000000000000000000000000000000", // USDT
  //   "0x4441490000000000000000000000000000000000000000000000000000000000", // DAI
  //   "0x4141504c00000000000000000000000000000000000000000000000000000000", // AAPL
  //   "0x4a50590000000000000000000000000000000000000000000000000000000000", // JPY
  //   "0x5841550000000000000000000000000000000000000000000000000000000000", // XAU
  //   "0x414d5a4e00000000000000000000000000000000000000000000000000000000", // AMZN
  //   "0x4d53465400000000000000000000000000000000000000000000000000000000", // MSFT
  //   "0x54534c4100000000000000000000000000000000000000000000000000000000", // TSLA
  //   "0x4555520000000000000000000000000000000000000000000000000000000000", // EUR
  //   "0x5841470000000000000000000000000000000000000000000000000000000000", // XAG
  //   "0x474c500000000000000000000000000000000000000000000000000000000000", // GLP
  //   ethers.utils.formatBytes32String("AUD"),
  //   ethers.utils.formatBytes32String("GBP"),
  //   ethers.utils.formatBytes32String("ADA"),
  //   ethers.utils.formatBytes32String("MATIC"),
  //   ethers.utils.formatBytes32String("SUI"),
  //   ethers.utils.formatBytes32String("ARB"),
  //   ethers.utils.formatBytes32String("OP"),
  //   ethers.utils.formatBytes32String("LTC"),
  //   ethers.utils.formatBytes32String("COIN"),
  //   ethers.utils.formatBytes32String("GOOG"),
  //   ethers.utils.formatBytes32String("BNB"),
  //   ethers.utils.formatBytes32String("SOL"),
  //   ethers.utils.formatBytes32String("QQQ"),
  //   ethers.utils.formatBytes32String("XRP"),
  //   ethers.utils.formatBytes32String("NVDA"),
  //   ethers.utils.formatBytes32String("LINK"),
  //   ethers.utils.formatBytes32String("CHF"),
  //   ethers.utils.formatBytes32String("DOGE"),
  //   ethers.utils.formatBytes32String("CAD"),
  //   ethers.utils.formatBytes32String("SGD"),
  //   ethers.utils.formatBytes32String("wstETH"),
  //   ethers.utils.formatBytes32String("CNH"),
  //   ethers.utils.formatBytes32String("HKD"),
  //   ethers.utils.formatBytes32String("BCH"),
  //   ethers.utils.formatBytes32String("GM-BTCUSD"),
  //   ethers.utils.formatBytes32String("GM-ETHUSD"),
  // ]);
  // console.log((await ecoPyth.mapAssetIdToIndex(ethers.utils.formatBytes32String("SGD"))).toString());
  // console.log((await ecoPyth.mapAssetIdToIndex(ethers.utils.formatBytes32String("wstETH"))).toString());
  // console.log((await ecoPyth.mapAssetIdToIndex(ethers.utils.formatBytes32String("CNH"))).toString());
  // console.log((await ecoPyth.mapAssetIdToIndex(ethers.utils.formatBytes32String("HKD"))).toString());
  // console.log((await ecoPyth.mapAssetIdToIndex(ethers.utils.formatBytes32String("BCH"))).toString());
  // console.log((await ecoPyth.mapAssetIdToIndex(ethers.utils.formatBytes32String("GM-BTCUSD"))).toString());
  // console.log((await ecoPyth.mapAssetIdToIndex(ethers.utils.formatBytes32String("GM-ETHUSD"))).toString());
  // console.log((await ecoPyth.indexCount()).toString());
  console.log(await ecoPyth.getPriceUnsafe(ethers.utils.formatBytes32String("GM-BTCUSD")));
  console.log(await ecoPyth.getPriceUnsafe(ethers.utils.formatBytes32String("GM-ETHUSD")));
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
