import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { TradeOrderHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    { marketIndex: 0, positionSizeLimit: 1000000, tradeSizeLimit: 1000000 },
    { marketIndex: 1, positionSizeLimit: 1000000, tradeSizeLimit: 1000000 },
    { marketIndex: 2, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 3, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 4, positionSizeLimit: 500000, tradeSizeLimit: 500000 },
    { marketIndex: 5, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 6, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 7, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 8, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 9, positionSizeLimit: 500000, tradeSizeLimit: 500000 },
    { marketIndex: 10, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 11, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 12, positionSizeLimit: 400000, tradeSizeLimit: 400000 },
    { marketIndex: 13, positionSizeLimit: 300000, tradeSizeLimit: 300000 },
    { marketIndex: 14, positionSizeLimit: 300000, tradeSizeLimit: 300000 },
    { marketIndex: 15, positionSizeLimit: 400000, tradeSizeLimit: 400000 },
    { marketIndex: 16, positionSizeLimit: 400000, tradeSizeLimit: 400000 },
    { marketIndex: 17, positionSizeLimit: 400000, tradeSizeLimit: 400000 },
    { marketIndex: 18, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 19, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 20, positionSizeLimit: 500000, tradeSizeLimit: 500000 },
    { marketIndex: 21, positionSizeLimit: 1000000, tradeSizeLimit: 1000000 },
    { marketIndex: 22, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 23, positionSizeLimit: 750000, tradeSizeLimit: 750000 },
    { marketIndex: 24, positionSizeLimit: 500000, tradeSizeLimit: 1000000 },
    { marketIndex: 25, positionSizeLimit: 400000, tradeSizeLimit: 400000 },
    { marketIndex: 26, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 27, positionSizeLimit: 500000, tradeSizeLimit: 500000 },
    { marketIndex: 28, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 29, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 30, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 31, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 32, positionSizeLimit: 250000, tradeSizeLimit: 250000 },
    { marketIndex: 33, positionSizeLimit: 100000, tradeSizeLimit: 100000 },
    { marketIndex: 34, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 35, positionSizeLimit: 50000, tradeSizeLimit: 50000 },
    { marketIndex: 36, positionSizeLimit: 75000, tradeSizeLimit: 75000 },
    { marketIndex: 37, positionSizeLimit: 250000, tradeSizeLimit: 250000 },
    { marketIndex: 38, positionSizeLimit: 100000, tradeSizeLimit: 100000 },
    { marketIndex: 39, positionSizeLimit: 350000, tradeSizeLimit: 350000 },
    { marketIndex: 40, positionSizeLimit: 300000, tradeSizeLimit: 300000 },
    { marketIndex: 41, positionSizeLimit: 250000, tradeSizeLimit: 250000 },
    { marketIndex: 42, positionSizeLimit: 50000, tradeSizeLimit: 50000 },
    { marketIndex: 43, positionSizeLimit: 100000, tradeSizeLimit: 100000 },
    { marketIndex: 44, positionSizeLimit: 50000, tradeSizeLimit: 50000 },
    { marketIndex: 45, positionSizeLimit: 200000, tradeSizeLimit: 200000 },
    { marketIndex: 46, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
    { marketIndex: 47, positionSizeLimit: 100000, tradeSizeLimit: 100000 },
    { marketIndex: 48, positionSizeLimit: 100000, tradeSizeLimit: 100000 },
    { marketIndex: 49, positionSizeLimit: 2000000, tradeSizeLimit: 2000000 },
  ];

  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const tradeOrderHelper = TradeOrderHelper__factory.connect(config.helpers.tradeOrder, deployer);

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
    tradeOrderHelper.address,
    tradeOrderHelper.interface.encodeFunctionData("setLimit", [
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
