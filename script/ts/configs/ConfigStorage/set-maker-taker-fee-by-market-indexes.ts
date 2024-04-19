import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const inputs = [
    {
      marketIndex: 0,
      makerFee: (0.02 / 100) * 1e8,
      takerFee: (0.04 / 100) * 1e8,
    },
    {
      marketIndex: 1,
      makerFee: (0.01 / 100) * 1e8,
      takerFee: (0.04 / 100) * 1e8,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Set Maker/Taker Fee...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setMakerTakerFeeByMarketIndexes", [
      inputs.map((e) => e.marketIndex),
      inputs.map((e) => e.makerFee),
      inputs.map((e) => e.takerFee),
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
