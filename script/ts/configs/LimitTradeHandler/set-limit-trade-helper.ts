import { LimitTradeHandler__factory } from "../../../../typechain";
import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  console.log("> LimitTradeHandler: Set Limit Trade Helper...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await (await limitTradeHandler.setLimitTradeHelper(config.helpers.limitTrade)).wait();
  console.log("> LimitTradeHandler: Set Limit Trade Helper success!");
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
