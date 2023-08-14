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
      marketIndex: 0, // ETHUSD
      weightBPS: 4 * BPS,
    },
    {
      marketIndex: 1, // BTCUSD
      weightBPS: 4 * BPS,
    },
    {
      marketIndex: 2, // AAPLUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 3, // JPYUSD
      weightBPS: BPS,
    },
    {
      marketIndex: 4, // XAUUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 5, // AMZNUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 6, // MSFTUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 7, // TSLAUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 8, // EURUSD
      weightBPS: BPS,
    },
    {
      marketIndex: 9, // XAGUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 10, // AUDUSD
      weightBPS: BPS,
    },
    {
      marketIndex: 11, // GBPUSD
      weightBPS: BPS,
    },
    {
      marketIndex: 12, // ADAUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 13, // MATICUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 14, // SUIUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 15, // ARBUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 16, // OPUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 17, // LTCUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 18, // COINUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 19, // GOOGUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 20, // BNBUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 21, // SOLUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 22, // QQQUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 23, // XRPUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 24, // NVDAUSD
      weightBPS: 5 * BPS,
    },
    {
      marketIndex: 25, // LINKUSD
      weightBPS: 7 * BPS,
    },
    {
      marketIndex: 26, // CHFUSD
      weightBPS: BPS,
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
