import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const inputs = [
    { marketIndex: 27, minProfitDuration: 300 },
    { marketIndex: 28, minProfitDuration: 60 },
    { marketIndex: 29, minProfitDuration: 60 },
  ];

  const safeWrapper = new SafeWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const owner = await configStorage.owner();

  console.log("[ConfigStorage] Set Min Profit Duration by Market Index...");
  if (compareAddress(owner, safeWrapper.getAddress())) {
    const tx = await safeWrapper.proposeTransaction(
      configStorage.address,
      0,
      configStorage.interface.encodeFunctionData("setMinProfitDurations", [
        inputs.map((each) => each.marketIndex),
        inputs.map((each) => each.minProfitDuration),
      ])
    );
    console.log(`[ConfigStorage] Tx: ${tx}`);
  } else {
    const tx = await configStorage.setMinProfitDurations(
      inputs.map((each) => each.marketIndex),
      inputs.map((each) => each.minProfitDuration)
    );
    console.log(`[ConfigStorage] Tx: ${tx}`);
    await tx.wait();
  }

  console.log("[ConfigStorage] Finished");
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
