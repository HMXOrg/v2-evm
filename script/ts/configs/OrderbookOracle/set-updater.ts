import { OrderbookOracle__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, signers.deployer(chainId));

  const inputs = [
    { updater: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a", isUpdater: true },
    { updater: "0x0578C797798Ae89b688Cd5676348344d7d0EC35E", isUpdater: true },
  ];

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
