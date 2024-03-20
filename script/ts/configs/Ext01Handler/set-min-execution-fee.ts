import { Ext01Handler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import signers from "../../entities/signers";
import { compareAddress } from "../../utils/address";
import { ethers } from "ethers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

enum OrderType {
  SwithCollateral = 1,
  TransferCollateral = 2,
}

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const ext01Handler = Ext01Handler__factory.connect(config.handlers.ext01, deployer);

  const PARAMS = [
    {
      orderType: OrderType.TransferCollateral,
      minExecutionFee: ethers.utils.parseEther("0.000008"),
    },
    {
      orderType: OrderType.SwithCollateral,
      minExecutionFee: ethers.utils.parseEther("0.00002"),
    },
  ];

  for (const p of PARAMS) {
    console.log(
      `[config/Ext01Handler] Set min execution fee for ${p.orderType} to ${ethers.utils.formatEther(
        p.minExecutionFee
      )} ETH`
    );
    await ownerWrapper.authExec(
      ext01Handler.address,
      ext01Handler.interface.encodeFunctionData("setMinExecutionFee", [p.orderType, p.minExecutionFee])
    );
  }
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
