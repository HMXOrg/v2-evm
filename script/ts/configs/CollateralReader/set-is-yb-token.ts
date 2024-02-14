import { CollateralReader__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const collateralReader = CollateralReader__factory.connect(config.reader.collateral!, deployer);

  const inputs = [
    {
      ybToken: config.tokens.ybeth!,
      isYb: true,
    },
    { ybToken: config.tokens.ybusdb!, isYb: true },
  ];

  console.log("[configs/CollateralReader] Set Is YbToken...");
  await ownerWrapper.authExec(
    collateralReader.address,
    collateralReader.interface.encodeFunctionData("setIsYbToken", [
      inputs.map((each) => each.ybToken) as string[],
      inputs.map((each) => each.isYb) as boolean[],
    ])
  );
  console.log("[configs/CollateralReader] Finished");
  console.log("[configs/CollateralReader] Set ybToken of success!");
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
