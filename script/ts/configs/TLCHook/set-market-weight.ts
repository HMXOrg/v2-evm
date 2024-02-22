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
    {
      marketIndex: 41, // STRKUSD
      weightBPS: 5 * BPS,
    },
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
