import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("AUD"),
    pythPriceId: ethers.utils.formatBytes32String("AUD"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("GBP"),
    pythPriceId: ethers.utils.formatBytes32String("GBP"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("ADA"),
    pythPriceId: ethers.utils.formatBytes32String("ADA"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("MATIC"),
    pythPriceId: ethers.utils.formatBytes32String("MATIC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("SUI"),
    pythPriceId: ethers.utils.formatBytes32String("SUI"),
    inverse: false,
  },
];

async function main() {
  const config = loadConfig(42161);
  const deployer = signers.deployer(42161);
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("[PythAdapter] Setting configs...");

  const tx = await pythAdapter.setConfigs(
    inputs.map((each) => each.assetId),
    inputs.map((each) => each.pythPriceId),
    inputs.map((each) => each.inverse)
  );
  console.log(`[PythAdapter] Tx: ${tx.hash}`);
  console.log("[PythAdapter] Finished");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
