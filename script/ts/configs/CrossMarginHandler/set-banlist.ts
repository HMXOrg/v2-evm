import signers from "../../entities/signers";
import { Command } from "commander";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const users: Array<string> = ["0xbfd5dfd7dccfb83d49d788c71b7ac27a002b3159"];
  const isBanned: Array<boolean> = [true];

  console.log("[configs/CrossMarginHandler] Set banlist");
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  await ownerWrapper.authExec(
    crossMarginHandler.address,
    crossMarginHandler.interface.encodeFunctionData("setBanlist", [users, isBanned])
  );
  console.log("[configs/CrossMarginHandler] Done");
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "Chain ID", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
