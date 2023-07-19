import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { RebalanceHLPHandler__factory } from "../../../../typechain";
import { getUpdatePriceData } from "../../utils/price";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import chains from "../../entities/chains";
import { Address } from "wagmi";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

type WithdrawGlpParams = {
  token: Address;
  glpAmount: BigNumber;
  minOut: number;
};

async function main() {
  const chainId: number = 42161;
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const signer = signers.deployer(chainId);

  const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
    await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);

  console.log("[RebalanceHLP] executeWithdrawGLP...");
  const handler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP, signer);
  const params: [WithdrawGlpParams] = [
    {
      token: "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8",
      glpAmount: BigNumber.from("1000000000000000000"),
      minOut: 1000,
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

// const prog = new Command();
// prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

// prog.parse(process.argv);

// const opts = prog.opts();

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
