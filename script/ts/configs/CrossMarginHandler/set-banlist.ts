import signers from "../../entities/signers";
import { Command } from "commander";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const users: Array<string> = [
    "0x45f599bfca2fab3e8f5822ea1b0085f8982e16e6",
    "0x37eb10ac8a2745c1108fdf6756e52535b00f589c",
    "0x11777acba15878c3f82d4109df9e1f4799ac8925",
    "0x2462812f20b6e704fa0ac16c6e189103f267bb8f",
    "0xb3e475368ed0fa0ad23c04de0423d48a0758806f",
    "0x61007f6d18f6e480d46108cb4484bd99b42f32cd",
    "0xda72696cec7398b548f0b62fc094d0ab46c632d3",
  ];
  const isBanned: Array<boolean> = [true, true, true, true, true, true, true];

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
