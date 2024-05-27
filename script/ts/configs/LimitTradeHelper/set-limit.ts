import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const inputs = [
    { marketIndex: 35, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 42, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 41, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 32, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 17, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 12, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 47, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 43, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 13, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 48, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 40, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 38, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 14, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 36, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 33, tradeSizeLimit: 0, positionSizeLimit: 0 },
    { marketIndex: 37, tradeSizeLimit: 0, positionSizeLimit: 0 },
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
