import { BotHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";

const positionManagers = ["0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872"];

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);

  console.log("[configs/BotHandler] Proposing tx to set position managers");
  const tx = await safeWrapper.proposeTransaction(
    botHandler.address,
    0,
    botHandler.interface.encodeFunctionData("setPositionManagers", [positionManagers, true])
  );
  console.log(`[configs/BotHandler] Proposed: ${tx}`);
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
