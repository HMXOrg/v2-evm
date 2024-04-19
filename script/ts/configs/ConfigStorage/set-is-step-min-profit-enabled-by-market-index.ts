import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [
    { marketIndex: 0, isEnabled: true },
    { marketIndex: 1, isEnabled: true },
    { marketIndex: 8, isEnabled: true },
    { marketIndex: 9, isEnabled: true },
    { marketIndex: 10, isEnabled: true },
    { marketIndex: 11, isEnabled: true },
    { marketIndex: 12, isEnabled: true },
    { marketIndex: 13, isEnabled: true },
    { marketIndex: 14, isEnabled: true },
    { marketIndex: 15, isEnabled: true },
    { marketIndex: 16, isEnabled: true },
    { marketIndex: 17, isEnabled: true },
    { marketIndex: 19, isEnabled: true },
    { marketIndex: 24, isEnabled: true },
    { marketIndex: 25, isEnabled: true },
    { marketIndex: 27, isEnabled: true },
    { marketIndex: 28, isEnabled: true },
    { marketIndex: 29, isEnabled: true },
    { marketIndex: 30, isEnabled: true },
    { marketIndex: 31, isEnabled: true },
    { marketIndex: 32, isEnabled: true },
    { marketIndex: 33, isEnabled: true },
    { marketIndex: 34, isEnabled: true },
    { marketIndex: 35, isEnabled: true },
    { marketIndex: 36, isEnabled: true },
    { marketIndex: 37, isEnabled: true },
    { marketIndex: 39, isEnabled: true },
    { marketIndex: 40, isEnabled: true },
    { marketIndex: 41, isEnabled: true },
    { marketIndex: 42, isEnabled: true },
    { marketIndex: 43, isEnabled: true },
    { marketIndex: 44, isEnabled: true },
    { marketIndex: 45, isEnabled: true },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Enable Step Min Profit Duration for Markets...");
  console.table(inputs);
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setIsStepMinProfitEnabledByMarketIndex", [
      inputs.map((e) => e.marketIndex),
      inputs.map((e) => e.isEnabled),
    ])
  );
  console.log("[config/ConfigStorage] Done");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
