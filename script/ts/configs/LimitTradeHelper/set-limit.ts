import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    {
      marketIndex: 0, // ETHUSD
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 1, // BTCUSD
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 2, // USDJPY
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 3, // XAUUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 4, // EURUSD
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 5, // XAGUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 6, // AUDUSD
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 7, // GBPUSD
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 8, // ADAUSD
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 9, // MATICUSD
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 10, // SUIUSD
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 11, // ARBUSD
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 12, // OPUSD
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 13, // LTCUSD
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 14, // BNBUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 15, // SOLUSD
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("1000000", 30),
    },
    {
      marketIndex: 16, // XRPUSD
      tradeSizeLimit: ethers.utils.parseUnits("750000", 30),
      positionSizeLimit: ethers.utils.parseUnits("750000", 30),
    },
    {
      marketIndex: 17, // LINKUSD
      tradeSizeLimit: ethers.utils.parseUnits("400000", 30),
      positionSizeLimit: ethers.utils.parseUnits("400000", 30),
    },
    {
      marketIndex: 18, // USDCHF
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 19, // DOGEUSD
      tradeSizeLimit: ethers.utils.parseUnits("500000", 30),
      positionSizeLimit: ethers.utils.parseUnits("500000", 30),
    },
    {
      marketIndex: 20, // USDCAD
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 21, // USDSGD
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 22, // USDCNH
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 23, // USDHKD
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 24, // BCHUSD
      tradeSizeLimit: ethers.utils.parseUnits("250000", 30),
      positionSizeLimit: ethers.utils.parseUnits("250000", 30),
    },
    {
      marketIndex: 25, // MEMEUSD
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 26, // DIXUSD
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 27, // JTOUSD
      tradeSizeLimit: ethers.utils.parseUnits("50000", 30),
      positionSizeLimit: ethers.utils.parseUnits("50000", 30),
    },
    {
      marketIndex: 28, // STXUSD
      tradeSizeLimit: ethers.utils.parseUnits("75000", 30),
      positionSizeLimit: ethers.utils.parseUnits("75000", 30),
    },
    {
      marketIndex: 29, // ORDIUSD
      tradeSizeLimit: ethers.utils.parseUnits("250000", 30),
      positionSizeLimit: ethers.utils.parseUnits("250000", 30),
    },
    {
      marketIndex: 30, // TIAUSD
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 31, // AVAXUSD
      tradeSizeLimit: ethers.utils.parseUnits("350000", 30),
      positionSizeLimit: ethers.utils.parseUnits("350000", 30),
    },
    {
      marketIndex: 32, // INJUSD
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30),
      positionSizeLimit: ethers.utils.parseUnits("300000", 30),
    },
    {
      marketIndex: 33, // DOTUSD
      tradeSizeLimit: ethers.utils.parseUnits("250000", 30),
      positionSizeLimit: ethers.utils.parseUnits("250000", 30),
    },
    {
      marketIndex: 34, // SEIUSD
      tradeSizeLimit: ethers.utils.parseUnits("50000", 30),
      positionSizeLimit: ethers.utils.parseUnits("50000", 30),
    },
    {
      marketIndex: 35, // ATOMUSD
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 36, // 1000PEPEUSD
      tradeSizeLimit: ethers.utils.parseUnits("50000", 30),
      positionSizeLimit: ethers.utils.parseUnits("50000", 30),
    },
    {
      marketIndex: 37, // 1000SHIBUSD
      tradeSizeLimit: ethers.utils.parseUnits("200000", 30),
      positionSizeLimit: ethers.utils.parseUnits("200000", 30),
    },
    {
      marketIndex: 38, // USDSEK
      tradeSizeLimit: ethers.utils.parseUnits("2000000", 30),
      positionSizeLimit: ethers.utils.parseUnits("2000000", 30),
    },
    {
      marketIndex: 39, // ICPUSD
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 40, // MANTAUSD
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
    {
      marketIndex: 41, // STRKUSD
      tradeSizeLimit: ethers.utils.parseUnits("200000", 30),
      positionSizeLimit: ethers.utils.parseUnits("200000", 30),
    },
    {
      marketIndex: 42, // PYTHUSD
      tradeSizeLimit: ethers.utils.parseUnits("100000", 30),
      positionSizeLimit: ethers.utils.parseUnits("100000", 30),
    },
  ];

  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const limitTradeHelper = LimitTradeHelper__factory.connect(config.helpers.limitTrade!, deployer);

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
  await ownerWrapper.authExec(
    limitTradeHelper.address,
    limitTradeHelper.interface.encodeFunctionData("setLimit", [
      inputs.map((input) => input.marketIndex),
      inputs.map((input) => input.positionSizeLimit),
      inputs.map((input) => input.tradeSizeLimit),
    ])
  );
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
