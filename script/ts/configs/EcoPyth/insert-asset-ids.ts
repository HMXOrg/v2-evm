import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

const ASSET_IDS = [
  ethers.utils.formatBytes32String("ETH"),
  ethers.utils.formatBytes32String("BTC"),
  ethers.utils.formatBytes32String("USDC"),
  ethers.utils.formatBytes32String("DAI"),
  ethers.utils.formatBytes32String("JPY"),
  ethers.utils.formatBytes32String("XAU"),
  ethers.utils.formatBytes32String("EUR"),
  ethers.utils.formatBytes32String("XAG"),
  ethers.utils.formatBytes32String("AUD"),
  ethers.utils.formatBytes32String("GBP"),
  ethers.utils.formatBytes32String("ADA"),
  ethers.utils.formatBytes32String("MATIC"),
  ethers.utils.formatBytes32String("SUI"),
  ethers.utils.formatBytes32String("ARB"),
  ethers.utils.formatBytes32String("OP"),
  ethers.utils.formatBytes32String("LTC"),
  ethers.utils.formatBytes32String("BNB"),
  ethers.utils.formatBytes32String("SOL"),
  ethers.utils.formatBytes32String("XRP"),
  ethers.utils.formatBytes32String("LINK"),
  ethers.utils.formatBytes32String("CHF"),
  ethers.utils.formatBytes32String("DOGE"),
  ethers.utils.formatBytes32String("CAD"),
  ethers.utils.formatBytes32String("SGD"),
  ethers.utils.formatBytes32String("CNH"),
  ethers.utils.formatBytes32String("HKD"),
  ethers.utils.formatBytes32String("BCH"),
  ethers.utils.formatBytes32String("MEME"),
  ethers.utils.formatBytes32String("SEK"),
  ethers.utils.formatBytes32String("DIX"),
  ethers.utils.formatBytes32String("JTO"),
  ethers.utils.formatBytes32String("STX"),
  ethers.utils.formatBytes32String("ORDI"),
  ethers.utils.formatBytes32String("TIA"),
  ethers.utils.formatBytes32String("AVAX"),
  ethers.utils.formatBytes32String("INJ"),
  ethers.utils.formatBytes32String("DOT"),
  ethers.utils.formatBytes32String("SEI"),
  ethers.utils.formatBytes32String("ATOM"),
  ethers.utils.formatBytes32String("1000PEPE"),
  ethers.utils.formatBytes32String("1000SHIB"),
  ethers.utils.formatBytes32String("ICP"),
  ethers.utils.formatBytes32String("MANTA"),
  ethers.utils.formatBytes32String("STRK"),
  ethers.utils.formatBytes32String("PYTH"),
  ethers.utils.formatBytes32String("PENDLE"),
  ethers.utils.formatBytes32String("W"),
  ethers.utils.formatBytes32String("ENA"),
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
