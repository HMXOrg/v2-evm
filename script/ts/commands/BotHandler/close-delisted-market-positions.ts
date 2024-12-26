import { BotHandler__factory, PerpStorage__factory } from "../../../../typechain";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import * as readlineSync from "readline-sync";
import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import { getUpdatePriceData } from "../../utils/price";
import signers from "../../entities/signers";
import chains from "../../entities/chains";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const deployer = signers.deployer(chainId);
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);

  const chunkSize = 5;

  const perpStorage = PerpStorage__factory.connect(config.storages.perp, provider);
  const activePositions = await perpStorage.getActivePositions(1000, 0);
  const fxPositions = activePositions.filter((each) => [34].includes(each.marketIndex.toNumber()));

  console.table(
    fxPositions.map((each) => {
      return {
        primaryAccount: each.primaryAccount,
        subAccountId: each.subAccountId,
        marketIndex: each.marketIndex.toString(),
        positionSize: ethers.utils.formatUnits(each.positionSizeE30, 30),
      };
    })
  );
  const confirm = readlineSync.question(
    `[cmds/BotHandler] Confirm to force close these ${fxPositions.length} positions? (y/n): `
  );
  switch (confirm) {
    case "y":
      break;
    case "n":
      console.log("[cmds/BotHandler] Cancelled!");
      return;
    default:
      console.log("[cmds/BotHandler] Invalid input!");
      return;
  }

  console.log("[cmds/BotHandler] Closing positions...");
  const iterations = Math.ceil(fxPositions.length / chunkSize);
  for (let i = 0; i <= iterations; i++) {
    const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
      await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);
    const spliced = fxPositions.splice(0, chunkSize);
    if (spliced.length > 0) {
      const tx = await (
        await botHandler.closeDelistedMarketPositions(
          spliced.map((each) => each.primaryAccount),
          spliced.map((each) => each.subAccountId),
          spliced.map((each) => each.marketIndex),
          spliced.map((each) => config.tokens.usdc),
          priceUpdateData,
          publishTimeDiffUpdateData,
          minPublishedTime,
          hashedVaas
        )
      ).wait();

      console.log(`[cmds/BotHandler] Done: ${tx.transactionHash}`);
    }
  }
  console.log("[cmds/BotHandler] Close delisted positions success!");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
