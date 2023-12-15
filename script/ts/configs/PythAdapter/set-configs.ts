import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("1000SHIB"),
    pythPriceId: ethers.utils.formatBytes32String("1000SHIB"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("1000PEPE"),
    pythPriceId: ethers.utils.formatBytes32String("1000PEPE"),
    inverse: false,
  },
];

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("[configs/PythAdapter] Setting configs...");
  await await pythAdapter.setConfigs(
    inputs.map((each) => each.assetId),
    inputs.map((each) => each.pythPriceId),
    inputs.map((each) => each.inverse)
  );
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
