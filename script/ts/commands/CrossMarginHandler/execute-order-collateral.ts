import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CrossMarginHandler__factory, ERC20__factory } from "../../../../typechain";
import { ethers } from "ethers";
import { getUpdatePriceData } from "../../utils/price";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import chains from "../../entities/chains";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const signer = signers.deployer(chainId);

  console.log("[CrossMarginHandler] executeOrder...");
  const handler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, signer);
  const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
    await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);
  const tx = await handler.executeOrder(
    100,
    "0x257D2cA4dAeB7A0CdFAD4f6eC9045313628D85d9",
    priceUpdateData,
    publishTimeDiffUpdateData,
    minPublishedTime,
    hashedVaas
  );
  console.log(`[CrossMarginHandler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[CrossMarginHandler] Finished");
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
