import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { LimitTradeHandler__factory } from "../../../../typechain";
import { getUpdatePriceData } from "../../utils/price";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import chains from "../../entities/chains";
import * as readlineSync from "readline-sync";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const signer = signers.deployer(chainId);

  const accounts = ["0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a"];
  const subAccountIds = [0];
  const orderIndexes = [1];
  const feeReceiver = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";

  const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
    await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);
  console.table(readableTable);
  const confirm = readlineSync.question("Confirm to update price feeds? (y/n): ");
  switch (confirm) {
    case "y":
      break;
    case "n":
      console.log("Feed Price cancelled!");
      return;
    default:
      console.log("Invalid input!");
      return;
  }

  console.log("[LimitTradeHandler] executeOrder...");
  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, signer);
  const tx = await handler["executeOrders(address[],uint8[],uint256[],address,bytes32[],bytes32[],uint256,bytes32)"](
    accounts,
    subAccountIds,
    orderIndexes,
    feeReceiver,
    priceUpdateData,
    publishTimeDiffUpdateData,
    minPublishedTime,
    hashedVaas,
    { gasLimit: 10000000 }
  );
  console.log(`[LimitTradeHandler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[LimitTradeHandler] Finished");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
