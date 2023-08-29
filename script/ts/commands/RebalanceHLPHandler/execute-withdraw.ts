import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { RebalanceHLPHandler__factory } from "../../../../typechain";
import { getUpdatePriceData } from "../../utils/price";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import chains from "../../entities/chains";
import * as readlineSync from "readline-sync";
import { BigNumber, ethers } from "ethers";

const Zero = BigNumber.from(0);

type WithdrawGlpParams = {
  token: string;
  glpAmount: BigNumber;
  minOut: BigNumber;
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const signer = signers.deployer(chainId);

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

  console.log("[RebalanceHLP] executeWithdrawGLP...");
  const handler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP, signer);
  const params: WithdrawGlpParams[] = [
    {
      token: config.tokens.weth,
      glpAmount: ethers.utils.parseUnits("1000000", 18),
      minOut: Zero,
    },
    {
      token: config.tokens.weth,
      glpAmount: ethers.utils.parseUnits("1000000", 18),
      minOut: Zero,
    },
  ];
  const tx = await handler.withdrawGlp(
    params,
    priceUpdateData,
    publishTimeDiffUpdateData,
    minPublishedTime,
    hashedVaas,
    { gasLimit: 10000000 }
  );

  console.log(`[RebalanceHLPHandler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[RebalanceHLPHandler] Finished");
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
