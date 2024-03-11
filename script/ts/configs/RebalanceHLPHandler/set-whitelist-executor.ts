import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { RebalanceHLPHandler__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const user = "0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872"; // Deployer Address

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log(`[configs/RebalanceHLPHandler] Set whitelist to address: ${user}`);
  const handler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP!, deployer);
  await ownerWrapper.authExec(
    handler.address,
    handler.interface.encodeFunctionData("setWhitelistExecutor", [user, true])
  );
}

const prog = new Command();
prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
