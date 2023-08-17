import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

const ASSET_IDS = [
  ethers.utils.formatBytes32String("NVDA"),
  ethers.utils.formatBytes32String("LINK"),
  ethers.utils.formatBytes32String("CHF"),
];

async function main(chainId: number) {
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, deployer);
  const config = loadConfig(chainId);
  const safeWrappar = new SafeWrapper(chainId, deployer);

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);
  console.log("[EcoPyth] Inserting asset IDs...");
  const tx = await safeWrappar.proposeTransaction(
    ecoPyth.address,
    0,
    ecoPyth.interface.encodeFunctionData("insertAssetIds", [ASSET_IDS])
  );
  console.log(`[EcoPyth] Tx: ${tx}`);
  console.log("[EcoPyth] Finished");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
