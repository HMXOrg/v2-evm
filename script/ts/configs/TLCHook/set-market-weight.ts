import { TLCHook__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";

type WeightConfig = {
  marketIndex: number;
  weightBPS: number;
};

const BPS = 1e4;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  const weightConfigs: Array<WeightConfig> = [
    {
      marketIndex: 39, // AVAXUSD
      weightBPS: 3 * BPS,
    },
    {
      marketIndex: 40, // INJUSD
      weightBPS: 3 * BPS,
    },
    {
      marketIndex: 41, // SHIBUSD
      weightBPS: 3 * BPS,
    },
    {
      marketIndex: 42, // DOTUSD
      weightBPS: 3 * BPS,
    },
    {
      marketIndex: 43, // SEIUSD
      weightBPS: 3 * BPS,
    },
    {
      marketIndex: 44, // ATOMUSD
      weightBPS: 3 * BPS,
    },
    {
      marketIndex: 45, // PEPEUSD
      weightBPS: 3 * BPS,
    },
  ];

  const tlcHook = TLCHook__factory.connect(config.hooks.tlc, deployer);

  console.log("[configs/TLCHook] Adding new market config...");
  for (let i = 0; i < weightConfigs.length; i++) {
    const marketIndex = weightConfigs[i].marketIndex;
    const market = marketConfig.markets[marketIndex];
    console.log(`[configs/TLCHook] Set Weight for Market Index: ${market.name}...`);
    await (await tlcHook.setMarketWeight(marketIndex, weightConfigs[i].weightBPS)).wait();
  }
  console.log("[configs/TLCHook] Finished");
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
