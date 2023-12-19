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
    { marketIndex: 0, minProfitDuration: 15 },
    { marketIndex: 1, minProfitDuration: 15 },
    { marketIndex: 2, minProfitDuration: 60 },
    { marketIndex: 3, minProfitDuration: 60 },
    { marketIndex: 4, minProfitDuration: 60 },
    { marketIndex: 5, minProfitDuration: 60 },
    { marketIndex: 6, minProfitDuration: 60 },
    { marketIndex: 7, minProfitDuration: 60 },
    { marketIndex: 8, minProfitDuration: 60 },
    { marketIndex: 9, minProfitDuration: 60 },
    { marketIndex: 10, minProfitDuration: 60 },
    { marketIndex: 11, minProfitDuration: 60 },
    { marketIndex: 12, minProfitDuration: 300 },
    { marketIndex: 13, minProfitDuration: 300 },
    { marketIndex: 14, minProfitDuration: 300 },
    { marketIndex: 15, minProfitDuration: 300 },
    { marketIndex: 16, minProfitDuration: 300 },
    { marketIndex: 17, minProfitDuration: 300 },
    { marketIndex: 18, minProfitDuration: 60 },
    { marketIndex: 19, minProfitDuration: 60 },
    { marketIndex: 20, minProfitDuration: 60 },
    { marketIndex: 21, minProfitDuration: 300 },
    { marketIndex: 22, minProfitDuration: 60 },
    { marketIndex: 23, minProfitDuration: 60 },
    { marketIndex: 24, minProfitDuration: 60 },
    { marketIndex: 25, minProfitDuration: 300 },
    { marketIndex: 26, minProfitDuration: 60 },
    { marketIndex: 27, minProfitDuration: 300 },
    { marketIndex: 28, minProfitDuration: 60 },
    { marketIndex: 29, minProfitDuration: 60 },
    { marketIndex: 30, minProfitDuration: 60 },
    { marketIndex: 31, minProfitDuration: 60 },
    { marketIndex: 32, minProfitDuration: 60 },
    { marketIndex: 33, minProfitDuration: 60 },
    { marketIndex: 34, minProfitDuration: 60 },
    { marketIndex: 35, minProfitDuration: 300 },
    { marketIndex: 36, minProfitDuration: 300 },
    { marketIndex: 37, minProfitDuration: 300 },
    { marketIndex: 38, minProfitDuration: 300 },
    { marketIndex: 39, minProfitDuration: 300 },
    { marketIndex: 40, minProfitDuration: 300 },
    { marketIndex: 41, minProfitDuration: 300 },
    { marketIndex: 42, minProfitDuration: 300 },
    { marketIndex: 43, minProfitDuration: 300 },
    { marketIndex: 44, minProfitDuration: 300 },
  ];

  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const owner = await configStorage.owner();

  console.log("[configs/ConfigStorage] Set Min Profit Duration by Market Index...");
  if (compareAddress(owner, safeWrapper.getAddress())) {
    const tx = await safeWrapper.proposeTransaction(
      configStorage.address,
      0,
      configStorage.interface.encodeFunctionData("setMinProfitDurations", [
        inputs.map((each) => each.marketIndex),
        inputs.map((each) => each.minProfitDuration),
      ])
    );
    console.log(`[configs/ConfigStorage] Proposed Tx: ${tx}`);
  } else {
    const tx = await configStorage.setMinProfitDurations(
      inputs.map((each) => each.marketIndex),
      inputs.map((each) => each.minProfitDuration)
    );
    console.log(`[config/ConfigStorage] Tx: ${tx}`);
    await tx.wait();
  }
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
