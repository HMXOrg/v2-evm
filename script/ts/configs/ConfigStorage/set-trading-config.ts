import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";

const tradingConfig = {
  fundingInterval: 1, // second
  devFeeRateBPS: 1000, // 10%
  minProfitDuration: 0, // turn off min profit duration
  maxPosition: 10, // 10 positions per sub-account max
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[ConfigStorage] Set Trading Config...");
  const tx = await configStorage.setTradingConfig(tradingConfig);
  console.log(`[ConfigStorage] Tx: ${tx.hash}`);
  console.log("[ConfigStorage] Set Trading Config success!");
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
    process.exitCode = 1;
  });
