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
      tradeSizeLimit: ethers.utils.parseUnits("200000", 30),
      positionSizeLimit: ethers.utils.parseUnits("200000", 30),
    },
    {
      marketIndex: 1, // BTCUSD
      tradeSizeLimit: ethers.utils.parseUnits("200000", 30),
      positionSizeLimit: ethers.utils.parseUnits("200000", 30),
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
