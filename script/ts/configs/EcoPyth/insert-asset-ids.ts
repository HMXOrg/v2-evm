import { ethers } from "ethers";
import { EcoPyth__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

const ASSET_IDS = [ethers.utils.formatBytes32String("wstETH")];

async function main(chainId: number) {
  const deployer = signers.deployer(chainId);
  const config = loadConfig(chainId);
  const safeWrappar = new SafeWrapper(chainId, config.safe, deployer);

  const ecoPyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);
  console.log("[configs/EcoPyth] Inserting asset IDs...");
  const tx = await safeWrappar.proposeTransaction(
    ecoPyth.address,
    0,
    ecoPyth.interface.encodeFunctionData("insertAssetIds", [ASSET_IDS])
  );
  console.log(`[configs/EcoPyth] Tx: ${tx}`);
  console.log("[configs/EcoPyth] Finished");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
