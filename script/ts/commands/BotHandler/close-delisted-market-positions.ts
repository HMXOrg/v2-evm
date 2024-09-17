import { BotHandler__factory } from "../../../../typechain";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import * as readlineSync from "readline-sync";
import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import { getUpdatePriceData } from "../../utils/price";
import signers from "../../entities/signers";
import chains from "../../entities/chains";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const deployer = signers.deployer(chainId);
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);

  const chunkSize = 5;

  const accountList = [
    {
      account: "0xa177a530A85EB4A52a4fda73fe6b3099B79e6996",
      subAccountId: 0,
      marketIndex: 0,
      tpToken: config.tokens.ybusdb!,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 2,
      marketIndex: 2,
      tpToken: config.tokens.ybusdb!,
    },
  ];

  console.log("[cmds/BotHandler] Closing positions...");
  const iterations = Math.ceil(accountList.length / chunkSize);
  for (let i = 0; i <= iterations; i++) {
    const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
      await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);
    const spliced = accountList.splice(0, chunkSize);
    if (spliced.length > 0) {
      const tx = await (
        await botHandler.closeDelistedMarketPositions(
          spliced.map((each) => each.account),
          spliced.map((each) => each.subAccountId),
          spliced.map((each) => each.marketIndex),
          spliced.map((each) => each.tpToken),
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
