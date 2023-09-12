import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

const ASSET_IDS = [ethers.utils.formatBytes32String("WSTETH")];

async function main(chainId: number) {
  const deployer = signers.deployer(chainId);
  const config = loadConfig(chainId);

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);
  console.log("[EcoPyth] Inserting asset IDs...");
  await (await ecoPyth.insertAssetIds(ASSET_IDS)).wait();
  console.log("[EcoPyth] Finished");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
