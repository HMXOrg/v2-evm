import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Ext01Handler__factory } from "../../../../typechain";
import { getUpdatePriceData } from "../../utils/price";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import chains from "../../entities/chains";
import * as readlineSync from "readline-sync";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const signer = signers.deployer(chainId);

  const accounts = ["0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a"];
  const subAccountIds = [1];
  const orderIndexes = [4];
  const feeReceiver = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
  const isRevert = true;

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

  console.log("[Ext01Handler] executeOrder...");
  const handler = Ext01Handler__factory.connect(config.handlers.ext01, signer);
  const tx = await handler.executeOrders(
    accounts,
    subAccountIds,
    orderIndexes,
    feeReceiver,
    priceUpdateData,
    publishTimeDiffUpdateData,
    minPublishedTime,
    hashedVaas,
    isRevert,
    {
      gasLimit: 10000000,
    }
  );
  console.log(`[Ext01Handler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[Ext01Handler] Finished");
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
