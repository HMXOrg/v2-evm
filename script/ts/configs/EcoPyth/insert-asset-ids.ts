import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";

const ASSET_IDS = [ethers.utils.formatBytes32String("BNB"), ethers.utils.formatBytes32String("SOL")];

async function main(chainId: number) {
  const deployer = signers.deployer(chainId);
  const config = loadConfig(chainId);

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);
  console.log("[EcoPyth] Inserting asset IDs...");
  const tx = await ecoPyth.insertAssetIds(ASSET_IDS);
  console.log(`[EcoPyth] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[EcoPyth] Finished");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
