import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { PerpStorage__factory } from "../../../../typechain";
import chains from "../../entities/chains";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const signer = signers.deployer(chainId);

  const perpStorage = PerpStorage__factory.connect(config.storages.perp, provider);
  const activePositions = await perpStorage.getActivePositions(1000, 0);
  console.log("account,marketIndex,positionSizeE30");
  activePositions.forEach((each) => {
    console.log(`${each.primaryAccount},${each.marketIndex.toString()},${each.positionSizeE30.toString()}`);
  });
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
