import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const deployer = signers.deployer(chainId);
  const config = loadConfig(chainId);

  const index = 41;
  const ecoPythPriceId = ethers.utils.formatBytes32String("MEME");

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);
  console.log("[EcoPyth] Setting asset IDs...");
  await (await ecoPyth.setAssetId(index, ecoPythPriceId)).wait();
  console.log("[EcoPyth] Finished");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
