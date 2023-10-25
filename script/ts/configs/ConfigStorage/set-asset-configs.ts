import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      assetId: ethers.utils.formatBytes32String("GM-BTCUSD"),
      config: {
        assetId: ethers.utils.formatBytes32String("GM-BTCUSD"),
        tokenAddress: config.tokens.wstEth,
        decimals: 18,
        isStableCoin: false,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("GM-ETHUSD"),
      config: {
        assetId: ethers.utils.formatBytes32String("GM-ETHUSD"),
        tokenAddress: config.tokens.wstEth,
        decimals: 18,
        isStableCoin: false,
      },
    },
  ];

  console.log("[configs/ConfigStorage] Set Asset Configs...");
  await (
    await configStorage.setAssetConfigs(
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.config)
    )
  ).wait();
  // console.log(`[configs/ConfigStorage] Tx: ${tx}`);
  // console.log("[configs/ConfigStorage] Finished");
  // console.log("[configs/ConfigStorage] Set Asset Configs success!");
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
