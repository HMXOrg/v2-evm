import { Calculator__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  const calculator = Calculator__factory.connect(config.calculator, deployer);
  const owner = await calculator.owner();
  console.log(`[configs/Calculator] setTradeHelper`);
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      calculator.address,
      0,
      calculator.interface.encodeFunctionData("setTradeHelper", [config.helpers.trade])
    );
    console.log(`[configs/Calculator] Proposed tx: ${tx}`);
  } else {
    const tx = await calculator.setTradeHelper(config.helpers.trade);
    console.log(`[configs/Calculator] Tx: ${tx}`);
    await tx.wait();
  }
  console.log("[configs/Calculator] Finished");
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
