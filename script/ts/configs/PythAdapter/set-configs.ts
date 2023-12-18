import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

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

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("[configs/PythAdapter] Setting configs...");

  await (
    await pythAdapter.setConfigs(
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.pythPriceId),
      inputs.map((each) => each.inverse)
    )
  ).wait();
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
