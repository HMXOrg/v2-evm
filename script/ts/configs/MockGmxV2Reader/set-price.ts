import { MockGmxV2Reader__factory, TLCHook__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = signers.deployer(chainId);

  const reader = MockGmxV2Reader__factory.connect(config.vendors.gmxV2.reader, deployer);
  await reader.setPrice(config.tokens.gmBTCUSD, ethers.utils.parseUnits("1", 30));
  await reader.setPrice(config.tokens.gmETHUSD, ethers.utils.parseUnits("2", 30));
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
