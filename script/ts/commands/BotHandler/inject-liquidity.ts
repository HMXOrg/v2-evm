import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { BotHandler__factory, ERC20__factory } from "../../../../typechain";
import * as readlineSync from "readline-sync";
import collaterals from "../../entities/collaterals";
import { ethers } from "ethers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number, token: string, amount: string) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  if (!collaterals[token]) throw new Error(`[cmds/BotHandler] Invalid token ${token}`);

  console.log(`[cmds/BotHandler] Injecting ${amount} ${token} liquidity to HLP on chain ${chainId}...`);
  const confirm = readlineSync.question("[cmds/BotHandler] Confirm (Y/N): ");
  switch (confirm) {
    case "Y":
    case "y":
      break;
    default:
      console.log("[cmds/BotHandler] Cancelled.");
      return;
  }
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);
  const owner = await botHandler.owner();
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  // Check allowance
  console.log(`[cmds/BotHandler] Checking allowance...`);
  const injectingToken = ERC20__factory.connect(collaterals[token].address, deployer);
  const allowance = await injectingToken.allowance(owner, config.handlers.bot);
  const amountWei = ethers.utils.parseUnits(amount, collaterals[token].decimals);
  if (allowance.lt(amountWei)) {
    console.log(`[cmds/BotHandler] Approving ${amount} ${token}...`);
    await safeWrapper.proposeTransaction(
      injectingToken.address,
      0,
      injectingToken.interface.encodeFunctionData("approve", [config.handlers.bot, ethers.constants.MaxUint256])
    );
  }
  console.log(`[cmds/BotHandler] Approved ${amount} ${token}.`);

  await ownerWrapper.authExec(
    botHandler.address,
    botHandler.interface.encodeFunctionData("injectTokenToHlpLiquidity", [collaterals[token].address, amountWei])
  );
  console.log(`[cmds/BotHandler] Injected ${amount} ${token} liquidity to HLP on chain ${chainId}.`);
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);
program.requiredOption("--token <token>", "liquidity token symbol");
program.requiredOption("--amount <amount>", "amount");

const opts = program.parse(process.argv).opts();

main(opts.chainId, opts.token, opts.amount)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
