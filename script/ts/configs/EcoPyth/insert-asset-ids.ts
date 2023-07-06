import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";

const assertIds = [
  "0x4554480000000000000000000000000000000000000000000000000000000000", // ETH
  "0x4254430000000000000000000000000000000000000000000000000000000000", // BTC
  "0x5553444300000000000000000000000000000000000000000000000000000000", // USDC
  "0x5553445400000000000000000000000000000000000000000000000000000000", // USDT
  "0x4441490000000000000000000000000000000000000000000000000000000000", // DAI
  "0x4141504c00000000000000000000000000000000000000000000000000000000", // AAPL
  "0x4a50590000000000000000000000000000000000000000000000000000000000", // JPY
  "0x5841550000000000000000000000000000000000000000000000000000000000", // XAU
  "0x414d5a4e00000000000000000000000000000000000000000000000000000000", // AMZN
  "0x4d53465400000000000000000000000000000000000000000000000000000000", // MSFT
  "0x54534c4100000000000000000000000000000000000000000000000000000000", // TSLA
  "0x4555520000000000000000000000000000000000000000000000000000000000", // EUR
  "0x5841470000000000000000000000000000000000000000000000000000000000", // XAG
  "0x474c500000000000000000000000000000000000000000000000000000000000", // GLP
  ethers.utils.formatBytes32String("AUD"),
  ethers.utils.formatBytes32String("GBP"),
  ethers.utils.formatBytes32String("ADA"),
  ethers.utils.formatBytes32String("MATIC"),
  ethers.utils.formatBytes32String("SUI"),
  ethers.utils.formatBytes32String("ARB"),
  ethers.utils.formatBytes32String("OP"),
  ethers.utils.formatBytes32String("LTC"),
  ethers.utils.formatBytes32String("COIN"),
  ethers.utils.formatBytes32String("GOOG"),
];

async function main() {
  const deployer = signers.deployer(42161);
  const config = loadConfig(42161);

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);
  console.log("[EcoPyth] Inserting asset IDs...");
  const tx = await ecoPyth.insertAssetIds(assertIds);
  console.log(`[EcoPyth] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[EcoPyth] Finished");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
