import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const inputs = [
    { marketIndex: 0, minProfitDuration: 180 },
    { marketIndex: 1, minProfitDuration: 180 },
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
    { marketIndex: 12, minProfitDuration: 60 },
    { marketIndex: 13, minProfitDuration: 60 },
    { marketIndex: 14, minProfitDuration: 60 },
    { marketIndex: 15, minProfitDuration: 60 },
    { marketIndex: 16, minProfitDuration: 60 },
    { marketIndex: 17, minProfitDuration: 60 },
    { marketIndex: 18, minProfitDuration: 60 },
    { marketIndex: 19, minProfitDuration: 60 },
    { marketIndex: 20, minProfitDuration: 60 },
    { marketIndex: 21, minProfitDuration: 60 },
    { marketIndex: 22, minProfitDuration: 60 },
    { marketIndex: 23, minProfitDuration: 60 },
    { marketIndex: 24, minProfitDuration: 60 },
    { marketIndex: 25, minProfitDuration: 60 },
    { marketIndex: 26, minProfitDuration: 60 },
    { marketIndex: 27, minProfitDuration: 60 },
    { marketIndex: 28, minProfitDuration: 60 },
    { marketIndex: 29, minProfitDuration: 60 },
    { marketIndex: 30, minProfitDuration: 60 },
    { marketIndex: 31, minProfitDuration: 60 },
    { marketIndex: 32, minProfitDuration: 60 },
    { marketIndex: 33, minProfitDuration: 60 },
    { marketIndex: 34, minProfitDuration: 60 },
    { marketIndex: 35, minProfitDuration: 60 },
    { marketIndex: 36, minProfitDuration: 60 },
    { marketIndex: 37, minProfitDuration: 60 },
    { marketIndex: 38, minProfitDuration: 60 },
    { marketIndex: 39, minProfitDuration: 60 },
    { marketIndex: 40, minProfitDuration: 60 },
    { marketIndex: 41, minProfitDuration: 60 },
    { marketIndex: 42, minProfitDuration: 60 },
  ];

  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/ConfigStorage] Set Min Profit Duration by Market Index...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setMinProfitDurations", [
      inputs.map((each) => each.marketIndex),
      inputs.map((each) => each.minProfitDuration),
    ])
  );
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
