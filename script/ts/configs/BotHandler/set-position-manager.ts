import { BotHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const positionManagers = ["0x3231C08B500bb26e0654cb0338F135CeD44d6B84", "0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E"];

  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);

  console.log("[configs/BotHandler] Proposing tx to set position managers");
  await ownerWrapper.authExec(
    botHandler.address,
    botHandler.interface.encodeFunctionData("setPositionManagers", [positionManagers, true])
  );
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
