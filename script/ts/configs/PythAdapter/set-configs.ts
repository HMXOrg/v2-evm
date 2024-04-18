import { ethers } from "ethers";
import { PythAdapter__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

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
    assetId: ethers.utils.formatBytes32String("JPY"),
    pythPriceId: ethers.utils.formatBytes32String("JPY"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("XAU"),
    pythPriceId: ethers.utils.formatBytes32String("XAU"),
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
  {
    assetId: ethers.utils.formatBytes32String("ARB"),
    pythPriceId: ethers.utils.formatBytes32String("ARB"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("OP"),
    pythPriceId: ethers.utils.formatBytes32String("OP"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("LTC"),
    pythPriceId: ethers.utils.formatBytes32String("LTC"),
    inverse: false,
  },
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
  {
    assetId: ethers.utils.formatBytes32String("XRP"),
    pythPriceId: ethers.utils.formatBytes32String("XRP"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("LINK"),
    pythPriceId: ethers.utils.formatBytes32String("LINK"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("CHF"),
    pythPriceId: ethers.utils.formatBytes32String("CHF"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("DOGE"),
    pythPriceId: ethers.utils.formatBytes32String("DOGE"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("CAD"),
    pythPriceId: ethers.utils.formatBytes32String("CAD"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("SGD"),
    pythPriceId: ethers.utils.formatBytes32String("SGD"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("CNH"),
    pythPriceId: ethers.utils.formatBytes32String("CNH"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("HKD"),
    pythPriceId: ethers.utils.formatBytes32String("HKD"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("BCH"),
    pythPriceId: ethers.utils.formatBytes32String("BCH"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("MEME"),
    pythPriceId: ethers.utils.formatBytes32String("MEME"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("SEK"),
    pythPriceId: ethers.utils.formatBytes32String("SEK"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("DIX"),
    pythPriceId: ethers.utils.formatBytes32String("DIX"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("JTO"),
    pythPriceId: ethers.utils.formatBytes32String("JTO"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("STX"),
    pythPriceId: ethers.utils.formatBytes32String("STX"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("ORDI"),
    pythPriceId: ethers.utils.formatBytes32String("ORDI"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("TIA"),
    pythPriceId: ethers.utils.formatBytes32String("TIA"),
    inverse: false,
  },
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
  {
    assetId: ethers.utils.formatBytes32String("1000PEPE"),
    pythPriceId: ethers.utils.formatBytes32String("1000PEPE"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("1000SHIB"),
    pythPriceId: ethers.utils.formatBytes32String("1000SHIB"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("ICP"),
    pythPriceId: ethers.utils.formatBytes32String("ICP"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("MANTA"),
    pythPriceId: ethers.utils.formatBytes32String("MANTA"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("STRK"),
    pythPriceId: ethers.utils.formatBytes32String("STRK"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("PYTH"),
    pythPriceId: ethers.utils.formatBytes32String("PYTH"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("PENDLE"),
    pythPriceId: ethers.utils.formatBytes32String("PENDLE"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("W"),
    pythPriceId: ethers.utils.formatBytes32String("W"),
    inverse: false,
  },
  {
    assetId: ethers.utils.formatBytes32String("ENA"),
    pythPriceId: ethers.utils.formatBytes32String("ENA"),
    inverse: false,
  },
];

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);

  console.log("[configs/PythAdapter] Setting configs...");
  await ownerWrapper.authExec(
    pythAdapter.address,
    pythAdapter.interface.encodeFunctionData("setConfigs", [
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.pythPriceId),
      inputs.map((each) => each.inverse),
    ])
  );
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
