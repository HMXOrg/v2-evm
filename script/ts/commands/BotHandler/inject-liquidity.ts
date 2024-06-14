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

  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);
  const owner = await botHandler.owner();
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  await botHandler.removeTokenFromHlpLiquidity(config.tokens.usdt!, 18628136730);
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
