import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { ConfigStorage__factory } from "../../../../typechain";
import signers from "../../entities/signers";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  console.log(ethers.utils.formatBytes32String("1000SHIB"));
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
