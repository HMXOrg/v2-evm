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
    { marketIndex: 0, weightBPS: 30000 },
    { marketIndex: 1, weightBPS: 30000 },
    { marketIndex: 2, weightBPS: 15000 },
    { marketIndex: 3, weightBPS: 55000 },
    { marketIndex: 4, weightBPS: 15000 },
    { marketIndex: 5, weightBPS: 55000 },
    { marketIndex: 6, weightBPS: 15000 },
    { marketIndex: 7, weightBPS: 15000 },
    { marketIndex: 8, weightBPS: 55000 },
    { marketIndex: 9, weightBPS: 55000 },
    { marketIndex: 10, weightBPS: 55000 },
    { marketIndex: 11, weightBPS: 55000 },
    { marketIndex: 12, weightBPS: 55000 },
    { marketIndex: 13, weightBPS: 55000 },
    { marketIndex: 14, weightBPS: 55000 },
    { marketIndex: 15, weightBPS: 55000 },
    { marketIndex: 16, weightBPS: 55000 },
    { marketIndex: 17, weightBPS: 55000 },
    { marketIndex: 18, weightBPS: 15000 },
    { marketIndex: 19, weightBPS: 55000 },
    { marketIndex: 20, weightBPS: 15000 },
    { marketIndex: 21, weightBPS: 15000 },
    { marketIndex: 22, weightBPS: 15000 },
    { marketIndex: 23, weightBPS: 15000 },
    { marketIndex: 24, weightBPS: 55000 },
    { marketIndex: 25, weightBPS: 55000 },
    { marketIndex: 26, weightBPS: 15000 },
    { marketIndex: 27, weightBPS: 55000 },
    { marketIndex: 28, weightBPS: 55000 },
    { marketIndex: 29, weightBPS: 55000 },
    { marketIndex: 30, weightBPS: 55000 },
    { marketIndex: 31, weightBPS: 55000 },
    { marketIndex: 32, weightBPS: 55000 },
    { marketIndex: 33, weightBPS: 55000 },
    { marketIndex: 34, weightBPS: 55000 },
    { marketIndex: 35, weightBPS: 55000 },
    { marketIndex: 36, weightBPS: 55000 },
    { marketIndex: 37, weightBPS: 55000 },
    { marketIndex: 38, weightBPS: 15000 },
    { marketIndex: 39, weightBPS: 55000 },
    { marketIndex: 40, weightBPS: 55000 },
    { marketIndex: 41, weightBPS: 55000 },
    { marketIndex: 42, weightBPS: 55000 },
    { marketIndex: 43, weightBPS: 55000 },
    { marketIndex: 44, weightBPS: 55000 },
    { marketIndex: 45, weightBPS: 55000 },
  ];

  const tlcHook = TLCHook__factory.connect(config.hooks.tlc, deployer);

  console.log("[configs/TLCHook] Adding new market config...");
  for (let i = 0; i < weightConfigs.length; i++) {
    const marketIndex = weightConfigs[i].marketIndex;
    const market = marketConfig.markets[marketIndex];
    console.log(`[configs/TLCHook] Set Weight for Market Index: ${market.name}...`);
    await ownerWrapper.authExec(
      tlcHook.address,
      tlcHook.interface.encodeFunctionData("setMarketWeight", [marketIndex, weightConfigs[i].weightBPS])
    );
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
