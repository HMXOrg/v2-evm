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
      tradeSizeLimit: ethers.utils.parseUnits("750000", 30), // 750
      positionSizeLimit: ethers.utils.parseUnits("1500000", 30), // 1.5M
    },
    {
      assetClass: assetClasses.equity,
      tradeSizeLimit: ethers.utils.parseUnits("750000", 30), // 750
      positionSizeLimit: ethers.utils.parseUnits("1500000", 30), // 1.5M
    },
    {
      assetClass: assetClasses.commodities,
      tradeSizeLimit: ethers.utils.parseUnits("750000", 30), // 750
      positionSizeLimit: ethers.utils.parseUnits("1500000", 30), // 1.5M
    },
    {
      assetClass: assetClasses.forex,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30), // 2M
      positionSizeLimit: ethers.utils.parseUnits("3000000", 30), // 3M
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
