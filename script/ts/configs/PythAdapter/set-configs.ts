import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("AVAX"),
    pythPriceId: ethers.utils.formatBytes32String("AVAX"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("INJ"),
    pythPriceId: ethers.utils.formatBytes32String("INJ"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("DOT"),
    pythPriceId: ethers.utils.formatBytes32String("DOT"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("SEI"),
    pythPriceId: ethers.utils.formatBytes32String("SEI"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("ATOM"),
    pythPriceId: ethers.utils.formatBytes32String("ATOM"),
    inverse: false,
  },
];

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("[configs/PythAdapter] Setting configs...");
  const tx = await safeWrapper.proposeTransaction(
    pythAdapter.address,
    0,
    pythAdapter.interface.encodeFunctionData("setConfigs", [
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.pythPriceId),
      inputs.map((each) => each.inverse),
    ])
  );
  console.log(`[configs/PythAdapter] Tx: ${tx}`);
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
