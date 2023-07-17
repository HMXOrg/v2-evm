import { LimitTradeHandler__factory } from "../../../../typechain";
import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const positionSizeLimit = ethers.utils.parseUnits("1000", 30);
  const tradeSizeLimit = ethers.utils.parseUnits("100000", 30);

  console.log("> LimitTradeHandler: Set Position and Trade Size Limit...");
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await (await limitTradeHandler.setPositionSizeLimit(positionSizeLimit, tradeSizeLimit)).wait();
  console.log("> LimitTradeHandler: Set Position and Trade Size Limit success!");
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
