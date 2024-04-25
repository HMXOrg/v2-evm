import { OrderbookOracle__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, signers.deployer(chainId));

  const inputs = [0];

  const deployer = signers.deployer(chainId);
  const orderbookOracle = OrderbookOracle__factory.connect(config.oracles.orderbook, deployer);

  console.log("[configs/OrderbookOracle] Proposing to set market indexes...");
  const owner = await orderbookOracle.owner();
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      orderbookOracle.address,
      0,
      orderbookOracle.interface.encodeFunctionData("setMarketIndexes", [inputs])
    );
    console.log(`[configs/OrderbookOracle] Proposed tx: ${tx}`);
  } else {
    const tx = await orderbookOracle.setMarketIndexes(inputs);
    console.log(`[configs/OrderbookOracle] Proposed tx: ${tx.hash}`);
    await tx.wait();
  }
  console.log("[configs/OrderbookOracle] Set Market Indexes success!");
}

const program = new Command();

program.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
