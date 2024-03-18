import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    { marketIndex: 0, tradeSizeLimit: 200000, positionSizeLimit: 200000 },
    { marketIndex: 1, tradeSizeLimit: 200000, positionSizeLimit: 200000 },
    { marketIndex: 2, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 3, tradeSizeLimit: 100000, positionSizeLimit: 100000 },
    { marketIndex: 4, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 5, tradeSizeLimit: 100000, positionSizeLimit: 100000 },
    { marketIndex: 6, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 7, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 8, tradeSizeLimit: 60000, positionSizeLimit: 60000 },
    { marketIndex: 9, tradeSizeLimit: 60000, positionSizeLimit: 60000 },
    { marketIndex: 10, tradeSizeLimit: 60000, positionSizeLimit: 60000 },
    { marketIndex: 11, tradeSizeLimit: 80000, positionSizeLimit: 80000 },
    { marketIndex: 12, tradeSizeLimit: 80000, positionSizeLimit: 80000 },
    { marketIndex: 13, tradeSizeLimit: 80000, positionSizeLimit: 80000 },
    { marketIndex: 14, tradeSizeLimit: 100000, positionSizeLimit: 100000 },
    { marketIndex: 15, tradeSizeLimit: 200000, positionSizeLimit: 200000 },
    { marketIndex: 16, tradeSizeLimit: 150000, positionSizeLimit: 150000 },
    { marketIndex: 17, tradeSizeLimit: 80000, positionSizeLimit: 80000 },
    { marketIndex: 18, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 19, tradeSizeLimit: 100000, positionSizeLimit: 100000 },
    { marketIndex: 20, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 21, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 22, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 23, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 24, tradeSizeLimit: 50000, positionSizeLimit: 50000 },
    { marketIndex: 25, tradeSizeLimit: 20000, positionSizeLimit: 20000 },
    { marketIndex: 26, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 27, tradeSizeLimit: 10000, positionSizeLimit: 10000 },
    { marketIndex: 28, tradeSizeLimit: 15000, positionSizeLimit: 15000 },
    { marketIndex: 29, tradeSizeLimit: 50000, positionSizeLimit: 50000 },
    { marketIndex: 30, tradeSizeLimit: 20000, positionSizeLimit: 20000 },
    { marketIndex: 31, tradeSizeLimit: 70000, positionSizeLimit: 70000 },
    { marketIndex: 32, tradeSizeLimit: 60000, positionSizeLimit: 60000 },
    { marketIndex: 33, tradeSizeLimit: 50000, positionSizeLimit: 50000 },
    { marketIndex: 34, tradeSizeLimit: 10000, positionSizeLimit: 10000 },
    { marketIndex: 35, tradeSizeLimit: 20000, positionSizeLimit: 20000 },
    { marketIndex: 36, tradeSizeLimit: 10000, positionSizeLimit: 10000 },
    { marketIndex: 37, tradeSizeLimit: 40000, positionSizeLimit: 40000 },
    { marketIndex: 38, tradeSizeLimit: 400000, positionSizeLimit: 400000 },
    { marketIndex: 39, tradeSizeLimit: 20000, positionSizeLimit: 20000 },
    { marketIndex: 40, tradeSizeLimit: 20000, positionSizeLimit: 20000 },
    { marketIndex: 41, tradeSizeLimit: 40000, positionSizeLimit: 40000 },
    { marketIndex: 42, tradeSizeLimit: 20000, positionSizeLimit: 20000 },
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
