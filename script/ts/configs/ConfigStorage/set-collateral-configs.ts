import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

const BPS = 10000;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      assetId: ethers.utils.formatBytes32String("USDC"),
      collateralConfig: {
        collateralFactorBPS: 1 * BPS,
        accepted: true,
        settleStrategy: ethers.constants.AddressZero,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("DAI"),
      collateralConfig: {
        collateralFactorBPS: 1 * BPS,
        accepted: true,
        settleStrategy: ethers.constants.AddressZero,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("ETH"),
      collateralConfig: {
        collateralFactorBPS: 0.9 * BPS,
        accepted: true,
        settleStrategy: ethers.constants.AddressZero,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("BTC"),
      collateralConfig: {
        collateralFactorBPS: 0.9 * BPS,
        accepted: true,
        settleStrategy: ethers.constants.AddressZero,
      },
    },
  ];

  console.log("[configs/ConfigStorage] Set Collateral Configs...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setCollateralTokenConfigs", [
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.collateralConfig),
    ])
  );
  console.log("[configs/ConfigStorage] Set Collateral Configs success!");
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
