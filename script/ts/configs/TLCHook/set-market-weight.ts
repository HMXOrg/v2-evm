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
    { marketIndex: 0, weightBPS: 4 * BPS },
    { marketIndex: 1, weightBPS: 4 * BPS },
    { marketIndex: 4, weightBPS: 5 * BPS },
    { marketIndex: 9, weightBPS: 5 * BPS },
    { marketIndex: 12, weightBPS: 5 * BPS },
    { marketIndex: 13, weightBPS: 5 * BPS },
    { marketIndex: 14, weightBPS: 5 * BPS },
    { marketIndex: 15, weightBPS: 5 * BPS },
    { marketIndex: 16, weightBPS: 5 * BPS },
    { marketIndex: 17, weightBPS: 5 * BPS },
    { marketIndex: 20, weightBPS: 5 * BPS },
    { marketIndex: 21, weightBPS: 5 * BPS },
    { marketIndex: 23, weightBPS: 5 * BPS },
    { marketIndex: 25, weightBPS: 5 * BPS },
    { marketIndex: 27, weightBPS: 5 * BPS },
    { marketIndex: 32, weightBPS: 5 * BPS },
    { marketIndex: 33, weightBPS: 5 * BPS },
    { marketIndex: 35, weightBPS: 5 * BPS },
    { marketIndex: 36, weightBPS: 5 * BPS },
    { marketIndex: 37, weightBPS: 5 * BPS },
    { marketIndex: 38, weightBPS: 5 * BPS },
    { marketIndex: 39, weightBPS: 5 * BPS },
    { marketIndex: 40, weightBPS: 5 * BPS },
    { marketIndex: 41, weightBPS: 5 * BPS },
    { marketIndex: 42, weightBPS: 5 * BPS },
    { marketIndex: 43, weightBPS: 5 * BPS },
    { marketIndex: 44, weightBPS: 5 * BPS },
    { marketIndex: 45, weightBPS: 5 * BPS },
    { marketIndex: 47, weightBPS: 5 * BPS },
    { marketIndex: 48, weightBPS: 5 * BPS },
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
