import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import signers from "../../entities/signers";
import assetClasses from "../../entities/asset-classes";

async function main(chainId: number) {
  const INPUTS = [
    {
      assetClass: assetClasses.crypto,
      assetConfig: {
        baseBorrowingRate: ethers.utils.parseEther("0.0001").div(60).div(60), // 0.01% per hour
      },
    },
    {
      assetClass: assetClasses.equity,
      assetConfig: {
        baseBorrowingRate: ethers.utils.parseEther("0.0001").div(60).div(60), // 0.01% per hour
      },
    },
    {
      assetClass: assetClasses.forex,
      assetConfig: {
        baseBorrowingRate: ethers.utils.parseEther("0.0001").div(60).div(60), // 0.01% per hour
      },
    },
    {
      assetClass: assetClasses.commodities,
      assetConfig: {
        baseBorrowingRate: ethers.utils.parseEther("0.0001").div(60).div(60), // 0.01% per hour
      },
    },
  ];

  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  for (const input of INPUTS) {
    console.log(`[Configs/ConfigStorage] Set Asset Class Config: ${input.assetClass}`);
    console.log(`[Configs/ConfigStorage] Asset Config: ${JSON.stringify(input.assetConfig)}`);
    const tx = await safeWrapper.proposeTransaction(
      configStorage.address,
      0,
      configStorage.interface.encodeFunctionData("setAssetClassConfigByIndex", [input.assetClass, input.assetConfig])
    );
    console.log(`[Configs/ConfigStorage] Proposed Hash: ${tx}`);
  }
  console.log("[Configs/ConfigStorage] Done");
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
