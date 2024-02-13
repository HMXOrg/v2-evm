import { ethers } from "ethers";
import { CalcPriceLens__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const priceAdapters = [
    {
      priceId: ethers.utils.formatBytes32String("ybETH"),
      adapter: config.oracles.priceAdapters.ybeth!,
    },
    {
      priceId: ethers.utils.formatBytes32String("ybUSDB"),
      adapter: config.oracles.priceAdapters.ybusdb!,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const lens = CalcPriceLens__factory.connect(config.oracles.calcPriceLens, deployer);

  console.log("[configs/CalcPriceLens] Setting price adapters...");
  await ownerWrapper.authExec(
    lens.address,
    lens.interface.encodeFunctionData("setPriceAdapters", [
      priceAdapters.map((each) => each.priceId),
      priceAdapters.map((each) => each.adapter),
    ])
  );

  console.log("[configs/CalcPriceLens] Finished");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
