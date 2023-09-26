import { ethers } from "ethers";
import { OnChainPriceLens, OnChainPriceLens__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const priceAdapters = [
    {
      priceId: ethers.utils.formatBytes32String("GLP"),
      adapter: config.oracles.priceAdapters.glp,
    },
    {
      priceId: ethers.utils.formatBytes32String("wstETH"),
      adapter: config.oracles.priceAdapters.wstEth,
    },
  ];

  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const lens = OnChainPriceLens__factory.connect(config.oracles.onChainPriceLens, deployer);
  const owner = await lens.owner();

  console.log("[configs/OnChainPriceLens] Setting price adapters...");
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      lens.address,
      0,
      lens.interface.encodeFunctionData("setPriceAdapters", [
        priceAdapters.map((each) => each.priceId),
        priceAdapters.map((each) => each.adapter),
      ])
    );
    console.log(`[configs/OnChainPriceLens] Tx: ${tx}`);
  } else {
    const tx = await lens.setPriceAdapters(
      priceAdapters.map((each) => each.priceId),
      priceAdapters.map((each) => each.adapter)
    );
    console.log(`[configs/OnChainPriceLens] Tx: ${tx.hash}`);
  }

  console.log("[configs/OnChainPriceLens] Finished");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
