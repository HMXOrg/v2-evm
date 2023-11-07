import { ethers } from "ethers";
import { CalcPriceLens, CalcPriceLens__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const priceAdapters = [
    {
      priceId: ethers.utils.formatBytes32String("GM-BTCUSD"),
      adapter: config.oracles.priceAdapters.gmBTCUSD,
    },
    {
      priceId: ethers.utils.formatBytes32String("GM-ETHUSD"),
      adapter: config.oracles.priceAdapters.gmETHUSD,
    },
  ];

  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const lens = CalcPriceLens__factory.connect(config.oracles.calcPriceLens, deployer);
  const owner = await lens.owner();

  console.log("[configs/CalcPriceLens] Setting price adapters...");
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      lens.address,
      0,
      lens.interface.encodeFunctionData("setPriceAdapters", [
        priceAdapters.map((each) => each.priceId),
        priceAdapters.map((each) => each.adapter),
      ])
    );
    console.log(`[configs/CalcPriceLens] Tx: ${tx}`);
  } else {
    const tx = await lens.setPriceAdapters(
      priceAdapters.map((each) => each.priceId),
      priceAdapters.map((each) => each.adapter)
    );
    console.log(`[configs/CalcPriceLens] Tx: ${tx.hash}`);
  }

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
