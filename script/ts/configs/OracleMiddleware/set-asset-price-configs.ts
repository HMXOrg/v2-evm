import { ethers } from "ethers";
import { OracleMiddleware__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

async function main() {
  const config = loadConfig(42161);
  const assetConfigs = [
    {
      assetId: ethers.utils.formatBytes32String("ARB"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("OP"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("LTC"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("COIN"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("GOOG"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
  ];

  const deployer = signers.deployer(42161);
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("[OracleMiddleware] Setting asset price configs...");
  const tx = await oracle.setAssetPriceConfigs(
    assetConfigs.map((each) => each.assetId),
    assetConfigs.map((each) => each.confidenceThreshold),
    assetConfigs.map((each) => each.trustPriceAge),
    assetConfigs.map((each) => each.adapter)
  );
  console.log(`[OracleMiddleware] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[OracleMiddleware] Finished");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
