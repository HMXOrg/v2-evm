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
      tradeSizeLimit: 150000,
      positionSizeLimit: 150000,
    },
    {
      marketIndex: 1, // BTCUSD
      tradeSizeLimit: 150000,
      positionSizeLimit: 150000,
    },
    {
      marketIndex: 2, // USDJPY
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 3, // XAUUSD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 4, // EURUSD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 5, // XAGUSD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 6, // AUDUSD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 7, // GBPUSD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 18, // USDCHF
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 20, // USDCAD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 21, // USDSGD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 22, // USDCNH
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 23, // USDHKD
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 26, // DIX
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 38, // USDSEK
      tradeSizeLimit: 100000,
      positionSizeLimit: 100000,
    },
    {
      marketIndex: 11, // ARBUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 12, // OPUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 14, // BNBUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 15, // SOLUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 16, // XRPUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 17, // LINKUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 19, // DOGEUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 31, // AVAXUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 36, // 1000PEPEUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 37, // 1000SHIBUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 42, // PYTHUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 43, // PENDLEUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
    },
    {
      marketIndex: 45, // ENAUSD
      tradeSizeLimit: 75000,
      positionSizeLimit: 75000,
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
        positionSizeLimit: i.positionSizeLimit,
        tradeSizeLimit: i.tradeSizeLimit,
      };
    })
  );
  await ownerWrapper.authExec(
    limitTradeHelper.address,
    limitTradeHelper.interface.encodeFunctionData("setLimit", [
      inputs.map((input) => input.marketIndex),
      inputs.map((input) => ethers.utils.parseUnits(input.positionSizeLimit.toString(), 30)),
      inputs.map((input) => ethers.utils.parseUnits(input.tradeSizeLimit.toString(), 30)),
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
