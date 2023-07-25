import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";

const BPS = 10000;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      assetId: ethers.utils.formatBytes32String("ARB"),
      collateralConfig: {
        collateralFactorBPS: 0.85 * BPS,
        accepted: true,
        settleStrategy: ethers.constants.AddressZero,
      },
    },
  ];

  console.log("> ConfigStorage: Set Collateral Configs...");
  const tx = await configStorage.setCollateralTokenConfigs(
    inputs.map((each) => each.assetId),
    inputs.map((each) => each.collateralConfig)
  );
  console.log(`Tx hash: ${tx.hash}`);
  await tx.wait();
  console.log("> ConfigStorage: Set Collateral Configs success!");
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
