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

  const accountList = [
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 4,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 3,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 3,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 3,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 4,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 4,
      marketIndex: 18,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 4,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
  ];

  const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
    await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);
  console.table(readableTable);
  const confirm = readlineSync.question(`[cmds/BotHandler] Confirm to close delisted positions? (y/n): `);
  switch (confirm) {
    case "y":
      break;
    case "n":
      console.log("[cmds/BotHandler] Delist cancelled!");
      return;
    default:
      console.log("[cmds/BotHandler] Invalid input!");
      return;
  }

  console.log("[cmds/BotHandler] Closing positions...");
  const tx = await (
    await botHandler.closeDelistedMarketPositions(
      accountList.map((each) => each.account),
      accountList.map((each) => each.subAccountId),
      accountList.map((each) => each.marketIndex),
      accountList.map((each) => each.tpToken),
      priceUpdateData,
      publishTimeDiffUpdateData,
      minPublishedTime,
      hashedVaas
    )
  ).wait();
  console.log(`[cmds/BotHandler] Done: ${tx.transactionHash}`);
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
