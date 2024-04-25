import { GasService__factory, IntentHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const executionFeeInUsd = 0;
  const executionFeeTreasury = "0x7FDD623c90a0097465170EdD352Be27A9f3ad817";

  const gasService = GasService__factory.connect(config.services.gas, deployer);
  console.log(`[configs/GasService] Set Intent Executor`);
  await ownerWrapper.authExec(
    gasService.address,
    gasService.interface.encodeFunctionData("setParams", [executionFeeInUsd, executionFeeTreasury])
  );
  console.log("[configs/GasService] Finished");
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
