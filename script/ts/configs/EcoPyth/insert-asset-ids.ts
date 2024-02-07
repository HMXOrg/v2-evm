import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

const ASSET_IDS = [
  ethers.utils.formatBytes32String("DAI"),
  ethers.utils.formatBytes32String("JPY"),
  ethers.utils.formatBytes32String("XAU"), // XAUUSD
  ethers.utils.formatBytes32String("EUR"), // EURUSD
  ethers.utils.formatBytes32String("XAG"), // XAGUSD
  ethers.utils.formatBytes32String("AUD"), // AUDUSD
  ethers.utils.formatBytes32String("GBP"), // GBPUSD
  ethers.utils.formatBytes32String("ADA"), // ADAUSD
  ethers.utils.formatBytes32String("MATIC"), // MATICUSD
  ethers.utils.formatBytes32String("SUI"), // SUIUSD
  ethers.utils.formatBytes32String("ARB"), // ARBUSD
  ethers.utils.formatBytes32String("OP"), // OPUSD
  ethers.utils.formatBytes32String("LTC"), // LTCUSD
  ethers.utils.formatBytes32String("BNB"), // BNBUSD
  ethers.utils.formatBytes32String("SOL"), // SOLUSD
  ethers.utils.formatBytes32String("XRP"), // XRPUSD
  ethers.utils.formatBytes32String("LINK"), // LINKUSD
  ethers.utils.formatBytes32String("CHF"), // USDCHF
  ethers.utils.formatBytes32String("DOGE"), // DOGEUSD
  ethers.utils.formatBytes32String("CAD"), // USDCAD
  ethers.utils.formatBytes32String("SGD"), // USDSGD
  ethers.utils.formatBytes32String("CNH"), // USDCNH
  ethers.utils.formatBytes32String("HKD"), // USDHKD
  ethers.utils.formatBytes32String("BCH"), // BCHUSD
  ethers.utils.formatBytes32String("MEME"), // MEMEUSD
  ethers.utils.formatBytes32String("SEK"), // USDSEK
  ethers.utils.formatBytes32String("DIX"),
  ethers.utils.formatBytes32String("JTO"), // JTOUSD
  ethers.utils.formatBytes32String("STX"), // STXUSD
  ethers.utils.formatBytes32String("ORDI"), // ORDIUSD
  ethers.utils.formatBytes32String("TIA"), // TIAUSD
  ethers.utils.formatBytes32String("AVAX"), // AVAXUSD
  ethers.utils.formatBytes32String("INJ"), // INJUSD
  ethers.utils.formatBytes32String("DOT"), // DOTUSD
  ethers.utils.formatBytes32String("SEI"), // SEIUSD
  ethers.utils.formatBytes32String("ATOM"), // ATOMUSD
  ethers.utils.formatBytes32String("1000PEPE"), // PEPEUSD
  ethers.utils.formatBytes32String("1000SHIB"), // SHIBUSD
  ethers.utils.formatBytes32String("ICP"), // ICPUSD
  ethers.utils.formatBytes32String("MANTA"), // MANTAUSD
];

async function main(chainId: number) {
  const deployer = signers.deployer(chainId);
  const config = loadConfig(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);
  console.log("[configs/EcoPyth] Inserting asset IDs...");
  await ownerWrapper.authExec(ecoPyth.address, ecoPyth.interface.encodeFunctionData("insertAssetIds", [ASSET_IDS]));
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
