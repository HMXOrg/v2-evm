import { ethers } from "ethers";
import { TLCHook__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";

type WeightConfig = {
  marketIndex: number;
  weightBPS: number;
};

const BPS = 1e4;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = signers.deployer(chainId);

  const weightConfigs: Array<WeightConfig> = [
    {
      marketIndex: 24, // NVDAUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 25, // LINKUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 26, // USDCHF
      weightBPS: 1 * BPS,
    },
  ];

  const tlcHook = TLCHook__factory.connect(config.hooks.tlc, deployer);

  console.log("[TLCHook] Adding new market config...");
  for (let i = 0; i < weightConfigs.length; i++) {
    const marketIndex = weightConfigs[i].marketIndex;
    const market = marketConfig.markets[marketIndex];
    console.log(`[TLCHook] Set Weight for Market Index: ${market.name}...`);
    const tx = await tlcHook.setMarketWeight(weightConfigs[i].marketIndex, weightConfigs[i].weightBPS);
    console.log(`[TLCHook] Tx: ${tx.hash}`);
  }
  console.log("[TLCHook] Finished");
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
