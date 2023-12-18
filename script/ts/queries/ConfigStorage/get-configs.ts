import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { ConfigStorage__factory } from "../../../../typechain";
import signers from "../../entities/signers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  console.log(await configStorage.getLiquidityConfig());
  console.log(await configStorage.getMarketConfigByIndex(23));
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
