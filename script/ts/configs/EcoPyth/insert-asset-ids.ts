import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";

const assertIds = [
  ethers.utils.formatBytes32String("AUD"),
  ethers.utils.formatBytes32String("GBP"),
  ethers.utils.formatBytes32String("ADA"),
  ethers.utils.formatBytes32String("MATIC"),
  ethers.utils.formatBytes32String("SUI"),
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
