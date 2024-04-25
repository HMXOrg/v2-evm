import { OrderbookOracle__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, signers.deployer(chainId));

  const inputs = [{ updater: "0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E", isUpdater: true }];

  const deployer = signers.deployer(chainId);
  const orderbookOracle = OrderbookOracle__factory.connect(config.oracles.orderbook, deployer);

  console.log("[configs/OrderbookOracle] Proposing to set updaters...");
  await ownerWrapper.authExec(
    orderbookOracle.address,
    orderbookOracle.interface.encodeFunctionData("setUpdaters", [
      inputs.map((each) => each.updater),
      inputs.map((each) => each.isUpdater),
    ])
  );
  console.log("[configs/OrderbookOracle] Set Updaters success!");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
