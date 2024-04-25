import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { CIXPriceAdapter__factory } from "../../../../typechain";
import { ethers } from "ethers";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const cixPriceAdapter = CIXPriceAdapter__factory.connect(config.oracles.priceAdapters.dix, deployer);

  const cE8 = ethers.utils.parseUnits("47.46426", 8);
  const assetIds = [
    ethers.utils.formatBytes32String("EUR"),
    ethers.utils.formatBytes32String("JPY"),
    ethers.utils.formatBytes32String("GBP"),
    ethers.utils.formatBytes32String("CAD"),
    ethers.utils.formatBytes32String("SEK"),
    ethers.utils.formatBytes32String("CHF"),
  ];
  const weightsE8 = [
    ethers.utils.parseUnits("0.560", 8),
    ethers.utils.parseUnits("0.140", 8),
    ethers.utils.parseUnits("0.120", 8),
    ethers.utils.parseUnits("0.100", 8),
    ethers.utils.parseUnits("0.040", 8),
    ethers.utils.parseUnits("0.040", 8),
  ];

  const usdQuoteds = [
    true, // EURUSD
    false, // USDJPY
    true, // GBPUSD
    false, // USDCAD
    false, // USDSEK
    false, // USDCHF
  ];

  console.log(`[configs/CIXPriceAdapter] Set Config...`);
  if (compareAddress(await cixPriceAdapter.owner(), config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      cixPriceAdapter.address,
      0,
      cixPriceAdapter.interface.encodeFunctionData("setConfig", [cE8, assetIds, weightsE8, usdQuoteds])
    );
    console.log(`[configs/CIXPriceAdapter] Proposed tx to set limit by market index: ${tx}`);
  } else {
    const tx = await cixPriceAdapter.setConfig(cE8, assetIds, weightsE8, usdQuoteds);
    console.log(`[configs/CIXPriceAdapter] Send tx to set config: ${tx.hash}`);
    await tx.wait();
  }
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
