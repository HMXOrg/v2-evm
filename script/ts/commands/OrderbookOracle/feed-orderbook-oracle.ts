import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import chains from "../../entities/chains";
import HmxApiWrapper from "../../wrappers/HMXAPIWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const deployer = signers.deployer(chainId);
  const hmxApi = new HmxApiWrapper(chainId);
  console.log("[cmds/OrderbookOracle] Feed Orderbook Oracle Data...");
  await hmxApi.refreshMarketIds();
  await hmxApi.feedOrderbookOracle();
  console.log("[cmds/OrderbookOracle] Success!");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
