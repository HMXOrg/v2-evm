import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    {
      marketIndex: 39,
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
  ];

  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const limitTradeHelper = LimitTradeHelper__factory.connect(config.helpers.limitTrade, deployer);

  console.log(`[configs/LimitTradeHelper] Set Limit By Market Index...`);
  console.table(
    inputs.map((i) => {
      return {
        marketIndex: i.marketIndex,
        market: marketConfig.markets[i.marketIndex].name,
        positionSizeLimit: ethers.utils.formatUnits(i.positionSizeLimit, 30),
        tradeSizeLimit: ethers.utils.formatUnits(i.tradeSizeLimit, 30),
      };
    })
  );
  const tx = await safeWrapper.proposeTransaction(
    limitTradeHelper.address,
    0,
    limitTradeHelper.interface.encodeFunctionData("setLimit", [
      inputs.map((input) => input.marketIndex),
      inputs.map((input) => input.positionSizeLimit),
      inputs.map((input) => input.tradeSizeLimit),
    ])
  );
  console.log(`[configs/LimitTradeHelper] Proposed tx to set limit by market index: ${tx}`);
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
