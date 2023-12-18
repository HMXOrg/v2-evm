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
      assetId: ethers.utils.formatBytes32String("ETH"),
      config: {
        assetId: ethers.utils.formatBytes32String("ETH"),
        tokenAddress: config.tokens.weth,
        decimals: 18,
        isStableCoin: false,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("BTC"),
      config: {
        assetId: ethers.utils.formatBytes32String("BTC"),
        tokenAddress: config.tokens.wbtc,
        decimals: 8,
        isStableCoin: false,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("DAI"),
      config: {
        assetId: ethers.utils.formatBytes32String("DAI"),
        tokenAddress: config.tokens.dai,
        decimals: 18,
        isStableCoin: true,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("USDC"),
      config: {
        assetId: ethers.utils.formatBytes32String("USDC"),
        tokenAddress: config.tokens.usdc,
        decimals: 6,
        isStableCoin: true,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("USDT"),
      config: {
        assetId: ethers.utils.formatBytes32String("USDT"),
        tokenAddress: config.tokens.usdt,
        decimals: 6,
        isStableCoin: true,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("GLP"),
      config: {
        assetId: ethers.utils.formatBytes32String("GLP"),
        tokenAddress: config.tokens.sglp,
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
  console.log("[configs/ConfigStorage] Finished");
  console.log("[configs/ConfigStorage] Set Asset Configs success!");
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
