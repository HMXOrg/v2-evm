import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("BNB"),
    pythPriceId: ethers.utils.formatBytes32String("BNB"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("SOL"),
    pythPriceId: ethers.utils.formatBytes32String("SOL"),
    inverse: false,
  },
];

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
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

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
