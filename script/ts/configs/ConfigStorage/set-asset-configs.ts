import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { IConfigStorage } from "../../../../typechain/src/storages/ConfigStorage";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      assetId: ethers.utils.formatBytes32String("ybETH2"),
      config: {
        assetId: ethers.utils.formatBytes32String("ybETH2"),
        tokenAddress: config.tokens.ybeth2,
        decimals: 18,
        isStableCoin: false,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("ybUSDB2"),
      config: {
        assetId: ethers.utils.formatBytes32String("ybUSDB2"),
        tokenAddress: config.tokens.ybusdb2,
        decimals: 18,
        isStableCoin: true,
      },
    },
  ];

  console.log("[configs/ConfigStorage] Set Asset Configs...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setAssetConfigs", [
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.config) as IConfigStorage.AssetConfigStruct[],
    ])
  );
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
