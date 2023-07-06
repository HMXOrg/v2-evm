import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("ARB"),
    pythPriceId: ethers.utils.formatBytes32String("ARB"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("OP"),
    pythPriceId: ethers.utils.formatBytes32String("OP"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("LTC"),
    pythPriceId: ethers.utils.formatBytes32String("LTC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("COIN"),
    pythPriceId: ethers.utils.formatBytes32String("COIN"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("GOOG"),
    pythPriceId: ethers.utils.formatBytes32String("GOOG"),
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
