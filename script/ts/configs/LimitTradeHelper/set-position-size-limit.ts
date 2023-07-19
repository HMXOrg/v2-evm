import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { ethers } from "ethers";
import { LimitTradeHelper__factory } from "../../../../typechain";
import assetClasses from "../../entities/asset-classes";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const assetClass = assetClasses.crypto;
  const positionSizeLimit = ethers.utils.parseUnits("500000", 30);
  const tradeSizeLimit = ethers.utils.parseUnits("300000", 30);

  console.log("> LimitTradeHelper: Set Position and Trade Size Limit...");
  const limitTradeHelper = LimitTradeHelper__factory.connect(config.helpers.limitTrade, deployer);
  await (await limitTradeHelper.setPositionSizeLimit(assetClass, positionSizeLimit, tradeSizeLimit)).wait();
  console.log("> LimitTradeHelper: Set Position and Trade Size Limit success!");
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
