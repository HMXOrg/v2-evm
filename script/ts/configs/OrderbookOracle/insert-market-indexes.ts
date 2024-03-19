import { OrderbookOracle__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const inputs = [
    8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 24, 25, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42,
  ];

  const orderbookOracle = OrderbookOracle__factory.connect(config.oracles.orderbook!, deployer);

  console.log("[configs/OrderbookOracle] Proposing to insert market indexes...");
  await ownerWrapper.authExec(
    orderbookOracle.address,
    orderbookOracle.interface.encodeFunctionData("insertMarketIndexes", [inputs])
  );
  console.log("[configs/OrderbookOracle] Insert Market Indexes success!");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
