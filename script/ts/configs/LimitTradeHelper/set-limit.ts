import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    {
      marketIndex: 0,
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 1,
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 3,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 4,
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 8,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 9,
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 10,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 11,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 12,
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 13,
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 14,
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 15,
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 16,
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 17,
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 20,
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 21,
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 23,
      tradeSizeLimit: ethers.utils.parseUnits("750000", 30),
      positionSizeLimit: ethers.utils.parseUnits("750000", 30),
    },
    {
      marketIndex: 25,
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 26,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 28,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 29,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 30,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 31,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 32,
      tradeSizeLimit: ethers.utils.parseUnits("250000", 30),
      positionSizeLimit: ethers.utils.parseUnits("250000", 30),
    },
    {
      marketIndex: 33,
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 34,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 35,
      tradeSizeLimit: ethers.utils.parseUnits("50000", 30),
      positionSizeLimit: ethers.utils.parseUnits("50000", 30),
    },
    {
      marketIndex: 36,
      tradeSizeLimit: ethers.utils.parseUnits("75000", 30),
      positionSizeLimit: ethers.utils.parseUnits("75000", 30),
    },
    {
      marketIndex: 37,
      tradeSizeLimit: ethers.utils.parseUnits("250000", 30),
      positionSizeLimit: ethers.utils.parseUnits("250000", 30),
    },
    {
      marketIndex: 38,
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 39,
      tradeSizeLimit: ethers.utils.parseUnits("350000", 30),
      positionSizeLimit: ethers.utils.parseUnits("350000", 30),
    },
    {
      marketIndex: 40,
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 41,
      tradeSizeLimit: ethers.utils.parseUnits("250000", 30),
      positionSizeLimit: ethers.utils.parseUnits("250000", 30),
    },
    {
      marketIndex: 42,
      tradeSizeLimit: ethers.utils.parseUnits("50000", 30),
      positionSizeLimit: ethers.utils.parseUnits("50000", 30),
    },
    {
      marketIndex: 43,
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 44,
      tradeSizeLimit: ethers.utils.parseUnits("200000", 30),
      positionSizeLimit: ethers.utils.parseUnits("200000", 30),
    },
    {
      marketIndex: 45,
      tradeSizeLimit: ethers.utils.parseUnits("200000", 30),
      positionSizeLimit: ethers.utils.parseUnits("200000", 30),
    },
    {
      marketIndex: 46,
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
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
