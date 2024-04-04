import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [
    { marketIndex: 0, isEnabled: true },
    { marketIndex: 1, isEnabled: true },
    { marketIndex: 12, isEnabled: true },
    { marketIndex: 13, isEnabled: true },
    { marketIndex: 14, isEnabled: true },
    { marketIndex: 15, isEnabled: true },
    { marketIndex: 16, isEnabled: true },
    { marketIndex: 17, isEnabled: true },
    { marketIndex: 20, isEnabled: true },
    { marketIndex: 21, isEnabled: true },
    { marketIndex: 23, isEnabled: true },
    { marketIndex: 25, isEnabled: true },
    { marketIndex: 27, isEnabled: true },
    { marketIndex: 32, isEnabled: true },
    { marketIndex: 33, isEnabled: true },
    { marketIndex: 35, isEnabled: true },
    { marketIndex: 36, isEnabled: true },
    { marketIndex: 37, isEnabled: true },
    { marketIndex: 38, isEnabled: true },
    { marketIndex: 39, isEnabled: true },
    { marketIndex: 40, isEnabled: true },
    { marketIndex: 41, isEnabled: true },
    { marketIndex: 42, isEnabled: true },
    { marketIndex: 43, isEnabled: true },
    { marketIndex: 44, isEnabled: true },
    { marketIndex: 45, isEnabled: true },
    { marketIndex: 47, isEnabled: true },
    { marketIndex: 48, isEnabled: true },
    { marketIndex: 49, isEnabled: true },
    { marketIndex: 50, isEnabled: true },
    { marketIndex: 51, isEnabled: true },
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
