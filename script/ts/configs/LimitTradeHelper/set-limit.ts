import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    { marketIndex: 0, tradeSizeLimit: 750000, positionSizeLimit: 1500000 },
    { marketIndex: 1, tradeSizeLimit: 750000, positionSizeLimit: 1500000 },
    { marketIndex: 2, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 3, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 4, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 5, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 6, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 7, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 8, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 9, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 10, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 11, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 12, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 13, tradeSizeLimit: 300000, positionSizeLimit: 300000 },
    { marketIndex: 14, tradeSizeLimit: 300000, positionSizeLimit: 300000 },
    { marketIndex: 15, tradeSizeLimit: 500000, positionSizeLimit: 500000 },
    { marketIndex: 16, tradeSizeLimit: 500000, positionSizeLimit: 500000 },
    { marketIndex: 17, tradeSizeLimit: 500000, positionSizeLimit: 500000 },
    { marketIndex: 18, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 19, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 20, tradeSizeLimit: 500000, positionSizeLimit: 500000 },
    { marketIndex: 21, tradeSizeLimit: 1000000, positionSizeLimit: 1000000 },
    { marketIndex: 22, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 23, tradeSizeLimit: 1000000, positionSizeLimit: 1000000 },
    { marketIndex: 24, tradeSizeLimit: 500000, positionSizeLimit: 1000000 },
    { marketIndex: 25, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 26, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 27, tradeSizeLimit: 500000, positionSizeLimit: 500000 },
    { marketIndex: 28, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 29, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 30, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 31, tradeSizeLimit: 2000000, positionSizeLimit: 3000000 },
    { marketIndex: 32, tradeSizeLimit: 500000, positionSizeLimit: 500000 },
    { marketIndex: 33, tradeSizeLimit: 100000, positionSizeLimit: 100000 },
    { marketIndex: 34, tradeSizeLimit: 2000000, positionSizeLimit: 2000000 },
    { marketIndex: 35, tradeSizeLimit: 75000, positionSizeLimit: 75000 },
    { marketIndex: 36, tradeSizeLimit: 75000, positionSizeLimit: 75000 },
    { marketIndex: 37, tradeSizeLimit: 250000, positionSizeLimit: 250000 },
    { marketIndex: 38, tradeSizeLimit: 50000, positionSizeLimit: 50000 },
    { marketIndex: 39, tradeSizeLimit: 500000, positionSizeLimit: 500000 },
    { marketIndex: 40, tradeSizeLimit: 300000, positionSizeLimit: 300000 },
    { marketIndex: 41, tradeSizeLimit: 250000, positionSizeLimit: 250000 },
    { marketIndex: 42, tradeSizeLimit: 100000, positionSizeLimit: 100000 },
    { marketIndex: 43, tradeSizeLimit: 100000, positionSizeLimit: 100000 },
    { marketIndex: 44, tradeSizeLimit: 200000, positionSizeLimit: 200000 },
  ].map((each) => {
    return {
      ...each,
      tradeSizeLimit: ethers.utils.parseUnits(each.tradeSizeLimit.toString(), 30),
      positionSizeLimit: ethers.utils.parseUnits(each.positionSizeLimit.toString(), 30),
    };
  });

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

  await (
    await limitTradeHelper.setLimit(
      inputs.map((input) => input.marketIndex),
      inputs.map((input) => input.positionSizeLimit),
      inputs.map((input) => input.tradeSizeLimit)
    )
  ).wait();
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
