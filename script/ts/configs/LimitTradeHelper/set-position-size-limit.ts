import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { ethers } from "ethers";
import { LimitTradeHelper__factory } from "../../../../typechain";
import assetClasses from "../../entities/asset-classes";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const inputs = [
    {
      assetClass: assetClasses.crypto,
      tradeSizeLimit: 0,
      positionSizeLimit: 0,
    },
    {
      assetClass: assetClasses.equity,
      tradeSizeLimit: 0, // 500k
      positionSizeLimit: 0, // 1M
    },
    {
      assetClass: assetClasses.commodities,
      tradeSizeLimit: 0, // 500k
      positionSizeLimit: 0, // 1M
    },
    {
      assetClass: assetClasses.forex,
      tradeSizeLimit: 0, // 500k
      positionSizeLimit: 0, // 1M
    },
  ];

  console.log("[configs/ConfigStorage] LimitTradeHelper: Set Position and Trade Size Limit...");
  const limitTradeHelper = LimitTradeHelper__factory.connect(config.helpers.limitTrade, deployer);
  const safeWrapper = new SafeWrapper(chainId, deployer);
  for (let i = 0; i < inputs.length; i++) {
    const tx = await safeWrapper.proposeTransaction(
      limitTradeHelper.address,
      0,
      limitTradeHelper.interface.encodeFunctionData("setPositionSizeLimit", [
        inputs[i].assetClass,
        inputs[i].positionSizeLimit,
        inputs[i].tradeSizeLimit,
      ])
    );
    console.log(`[configs/ConfigStorage] Proposed tx to update position size limit: ${tx}`);
  }
  console.log("[configs/ConfigStorage] Done");
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
