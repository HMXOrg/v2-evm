import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { ethers } from "ethers";
import { LimitTradeHelper__factory } from "../../../../typechain";
import assetClasses from "../../entities/asset-classes";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const inputs = [
    {
      assetClass: assetClasses.crypto,
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30), // 300k
      positionSizeLimit: ethers.utils.parseUnits("500000", 30), // 500k
    },
    {
      assetClass: assetClasses.equity,
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30), // 300k
      positionSizeLimit: ethers.utils.parseUnits("500000", 30), // 500k
    },
    {
      assetClass: assetClasses.commodities,
      tradeSizeLimit: ethers.utils.parseUnits("300000", 30), // 300k
      positionSizeLimit: ethers.utils.parseUnits("500000", 30), // 500k
    },
    {
      assetClass: assetClasses.forex,
      tradeSizeLimit: ethers.utils.parseUnits("1000000", 30), // 1M
      positionSizeLimit: ethers.utils.parseUnits("2500000", 30), // 2.5M
    },
  ];
  const assetClass = assetClasses.commodities;
  const positionSizeLimit = ethers.utils.parseUnits("500000", 30);
  const tradeSizeLimit = ethers.utils.parseUnits("300000", 30);

  console.log("> LimitTradeHelper: Set Position and Trade Size Limit...");
  const limitTradeHelper = LimitTradeHelper__factory.connect(config.helpers.limitTrade, deployer);
  const tx = await limitTradeHelper.setPositionSizeLimit(assetClass, positionSizeLimit, tradeSizeLimit);
  console.log(`Tx: ${tx.hash}`);
  await tx.wait();
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
