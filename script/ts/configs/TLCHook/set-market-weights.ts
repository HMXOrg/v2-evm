import { TLCHook__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

type WeightConfig = {
  marketIndex: number;
  weightBPS: number;
};

const BPS = 1e4;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const weightConfigs: Array<WeightConfig> = [
    { marketIndex: 0, weightBPS: 2 * BPS }, // ETHUSD
    { marketIndex: 1, weightBPS: 2 * BPS }, // BTCUSD
    { marketIndex: 2, weightBPS: 1 * BPS }, // USDJPY
    { marketIndex: 3, weightBPS: 5 * BPS }, // XAUUSD
    { marketIndex: 4, weightBPS: 1 * BPS }, // EURUSD
    { marketIndex: 5, weightBPS: 5 * BPS }, // XAGUSD
    { marketIndex: 6, weightBPS: 1 * BPS }, // AUDUSD
    { marketIndex: 7, weightBPS: 1 * BPS }, // GBPUSD
    { marketIndex: 8, weightBPS: 5 * BPS }, // ADAUSD
    { marketIndex: 9, weightBPS: 5 * BPS }, // MATICUSD
    { marketIndex: 10, weightBPS: 5 * BPS }, // SUIUSD
    { marketIndex: 11, weightBPS: 5 * BPS }, // ARBUSD
    { marketIndex: 12, weightBPS: 5 * BPS }, // OPUSD
    { marketIndex: 13, weightBPS: 5 * BPS }, // LTCUSD
    { marketIndex: 14, weightBPS: 5 * BPS }, // BNBUSD
    { marketIndex: 15, weightBPS: 5 * BPS }, // SOLUSD
    { marketIndex: 16, weightBPS: 5 * BPS }, // XRPUSD
    { marketIndex: 17, weightBPS: 5 * BPS }, // LINKUSD
    { marketIndex: 18, weightBPS: 1 * BPS }, // USDCHF
    { marketIndex: 19, weightBPS: 5 * BPS }, // DOGEUSD
    { marketIndex: 20, weightBPS: 1 * BPS }, // USDCAD
    { marketIndex: 21, weightBPS: 1 * BPS }, // USDSGD
    { marketIndex: 22, weightBPS: 1 * BPS }, // USDCNH
    { marketIndex: 23, weightBPS: 1 * BPS }, // USDHKD
    { marketIndex: 24, weightBPS: 5 * BPS }, // BCHUSD
    { marketIndex: 25, weightBPS: 5 * BPS }, // MEMEUSD
    { marketIndex: 26, weightBPS: 1 * BPS }, // DIXUSD
    { marketIndex: 27, weightBPS: 5 * BPS }, // JTOUSD
    { marketIndex: 28, weightBPS: 5 * BPS }, // STXUSD
    { marketIndex: 29, weightBPS: 5 * BPS }, // ORDIUSD
    { marketIndex: 30, weightBPS: 5 * BPS }, // TIAUSD
    { marketIndex: 31, weightBPS: 5 * BPS }, // AVAXUSD
    { marketIndex: 32, weightBPS: 5 * BPS }, // INJUSD
    { marketIndex: 33, weightBPS: 5 * BPS }, // DOTUSD
    { marketIndex: 34, weightBPS: 5 * BPS }, // SEIUSD
    { marketIndex: 35, weightBPS: 5 * BPS }, // ATOMUSD
    { marketIndex: 36, weightBPS: 5 * BPS }, // 1000PEPEUSD
    { marketIndex: 37, weightBPS: 5 * BPS }, // 1000SHIBUSD
    { marketIndex: 38, weightBPS: 1 * BPS }, // USDSEK
    { marketIndex: 39, weightBPS: 5 * BPS }, // ICPUSD
    { marketIndex: 40, weightBPS: 5 * BPS }, // MANTAUSD
    { marketIndex: 41, weightBPS: 5 * BPS }, // STRKUSD
    { marketIndex: 42, weightBPS: 5 * BPS }, // PYTHUSD
  ];

  const tlcHook = TLCHook__factory.connect(config.hooks.tlc, deployer);

  console.log(`[configs/TLCHook] Set Weight for Markets...`);
  await ownerWrapper.authExec(
    tlcHook.address,
    tlcHook.interface.encodeFunctionData("setMarketWeights", [
      weightConfigs.map((e) => e.marketIndex),
      weightConfigs.map((e) => e.weightBPS),
    ])
  );

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
