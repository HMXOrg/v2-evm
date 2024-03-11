import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import { EcoPyth2__factory } from "../../../../typechain";
import chains from "../../entities/chains";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const ecoPyth = EcoPyth2__factory.connect(config.oracles.ecoPyth2!, chains[chainId].jsonRpcProvider);
  const assetIds = await ecoPyth.getAssetIds();
  for (const aId of assetIds) {
    console.log(ethers.utils.parseBytes32String(aId));
  }
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
