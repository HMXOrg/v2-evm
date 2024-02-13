import { ethers } from "ethers";
import { OracleMiddleware__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const assetConfigs = [
    {
      assetId: ethers.utils.formatBytes32String("ETH"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("ybETH"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("BTC"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("USDC"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("ybUSDB"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("USDT"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("DAI"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("JPY"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("XAU"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("EUR"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("XAG"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("AUD"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("GBP"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("ADA"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("MATIC"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("SUI"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("ARB"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("OP"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("LTC"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("BNB"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("SOL"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("XRP"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("LINK"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("CHF"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("DOGE"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("CAD"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("SGD"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("CNH"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("HKD"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("BCH"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("MEME"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("SEK"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("DIX"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 60 * 24 * 3, // 3 days
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("JTO"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("STX"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("ORDI"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("TIA"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("AVAX"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("INJ"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("DOT"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("SEI"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("ATOM"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("1000PEPE"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("1000SHIB"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("ICP"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("MANTA"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("[configs/OracleMiddleware] Setting asset price configs...");
  await ownerWrapper.authExec(
    oracle.address,
    oracle.interface.encodeFunctionData("setAssetPriceConfigs", [
      assetConfigs.map((each) => each.assetId),
      assetConfigs.map((each) => each.confidenceThreshold),
      assetConfigs.map((each) => each.trustPriceAge),
      assetConfigs.map((each) => each.adapter),
    ])
  );
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
