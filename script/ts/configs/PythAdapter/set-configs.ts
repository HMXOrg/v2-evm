import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";

const inputs = [
  {
    assetId: ethers.utils.formatBytes32String("ETH"),
    pythPriceId: ethers.utils.formatBytes32String("ETH"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("BTC"),
    pythPriceId: ethers.utils.formatBytes32String("BTC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDC"),
    pythPriceId: ethers.utils.formatBytes32String("USDC"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("USDT"),
    pythPriceId: ethers.utils.formatBytes32String("USDT"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("DAI"),
    pythPriceId: ethers.utils.formatBytes32String("DAI"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("AAPL"),
    pythPriceId: ethers.utils.formatBytes32String("AAPL"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("JPY"),
    pythPriceId: ethers.utils.formatBytes32String("JPY"),
    inverse: true,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAU"),
    pythPriceId: ethers.utils.formatBytes32String("XAU"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("AMZN"),
    pythPriceId: ethers.utils.formatBytes32String("AMZN"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("MSFT"),
    pythPriceId: ethers.utils.formatBytes32String("MSFT"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("TSLA"),
    pythPriceId: ethers.utils.formatBytes32String("TSLA"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("EUR"),
    pythPriceId: ethers.utils.formatBytes32String("EUR"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAG"),
    pythPriceId: ethers.utils.formatBytes32String("XAG"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("GLP"),
    pythPriceId: ethers.utils.formatBytes32String("GLP"),
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
