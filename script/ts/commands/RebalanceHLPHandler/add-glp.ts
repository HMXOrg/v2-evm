import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { RebalanceHLPHandler__factory, VaultStorage__factory } from "../../../../typechain";
import { getUpdatePriceData } from "../../utils/price";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import chains from "../../entities/chains";
import * as readlineSync from "readline-sync";
import { BigNumber, ethers } from "ethers";
import SafeWrapper from "../../wrappers/SafeWrapper";

const ZEROADDRESS = ethers.constants.AddressZero;
const Zero = BigNumber.from(0);

type AddGlpParams = {
  token: string;
  tokenMedium: string;
  amount: BigNumber;
  minAmountOutUSD: BigNumber;
  minAmountOutGlp: BigNumber;
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const vault = VaultStorage__factory.connect(config.storages.vault, deployer);
  const handler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP, deployer);
  const params: AddGlpParams[] = [
    {
      token: config.tokens.dai,
      tokenMedium: ZEROADDRESS,
      amount: await vault.hlpLiquidity(config.tokens.dai),
      minAmountOutGlp: Zero,
      minAmountOutUSD: Zero,
    },
    {
      token: config.tokens.weth,
      tokenMedium: ZEROADDRESS,
      amount: await vault.hlpLiquidity(config.tokens.weth),
      minAmountOutGlp: Zero,
      minAmountOutUSD: Zero,
    },
    {
      token: config.tokens.usdt,
      tokenMedium: config.tokens.usdc,
      amount: await vault.hlpLiquidity(config.tokens.usdt),
      minAmountOutGlp: Zero,
      minAmountOutUSD: Zero,
    },
    {
      token: config.tokens.wbtc,
      tokenMedium: ZEROADDRESS,
      amount: await vault.hlpLiquidity(config.tokens.wbtc),
      minAmountOutGlp: Zero,
      minAmountOutUSD: Zero,
    },
    {
      token: config.tokens.arb,
      tokenMedium: config.tokens.weth,
      amount: await vault.hlpLiquidity(config.tokens.arb),
      minAmountOutGlp: Zero,
      minAmountOutUSD: Zero,
    },
  ];

  const provider = chains[chainId].jsonRpcProvider;

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
  console.log("[cmds/RebalanceHLP] Proposing reinvest GLP tx...");
  const tx = await safeWrapper.proposeTransaction(
    handler.address,
    0,
    handler.interface.encodeFunctionData("addGlp", [
      params,
      priceUpdateData,
      publishTimeDiffUpdateData,
      minPublishedTime,
      hashedVaas,
    ])
  );
  console.log(`[cmds/RebalanceHLPHandler] Proposed tx: ${tx}`);
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
