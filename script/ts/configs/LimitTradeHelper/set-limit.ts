import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    {
      marketIndex: 12, // ADAUSD
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 13, // MATICUSD
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 14, // SUIUSD
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 15, // ARBUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 16, // OPUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 17, // LTCUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 20, // BNBUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 21, // SOLUSD
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 23, // XRPUSD
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 25, // LINKUSD
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 27, // DOGEUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 32, // BCHUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 33, // MEMEUSD
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
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
