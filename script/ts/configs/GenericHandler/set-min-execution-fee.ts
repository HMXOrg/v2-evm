import {
  CrossMarginHandler__factory,
  CrossMarginService__factory,
  LimitTradeHandler__factory,
  LiquidityHandler__factory,
} from "../../../../typechain";
import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";
import { compareAddress } from "../../utils/address";

type GenericHandler_SetMinExecutionFee_Params = {
  handlerAddress: string;
  minExecutionFee: ethers.BigNumberish;
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const PARAMS: Array<GenericHandler_SetMinExecutionFee_Params> = [
    {
      handlerAddress: config.handlers.crossMargin,
      minExecutionFee: ethers.utils.parseEther("0.00001"),
    },
    {
      handlerAddress: config.handlers.limitTrade,
      minExecutionFee: ethers.utils.parseEther("0.00004"),
    },
    {
      handlerAddress: config.handlers.liquidity,
      minExecutionFee: ethers.utils.parseEther("0.00006"),
    },
  ];

  for (const param of PARAMS) {
    console.log(
      `[configs/GenericHandler] Set min execution fee for ${param.handlerAddress} to ${ethers.utils.formatEther(
        param.minExecutionFee
      )} ETH`
    );
    if (compareAddress(param.handlerAddress, config.handlers.crossMargin)) {
      const handler = CrossMarginHandler__factory.connect(param.handlerAddress, deployer);
      await ownerWrapper.authExec(
        handler.address,
        handler.interface.encodeFunctionData("setMinExecutionFee", [param.minExecutionFee])
      );
    } else if (compareAddress(param.handlerAddress, config.handlers.limitTrade)) {
      const handler = LimitTradeHandler__factory.connect(param.handlerAddress, deployer);
      await ownerWrapper.authExec(
        handler.address,
        handler.interface.encodeFunctionData("setMinExecutionFee", [param.minExecutionFee])
      );
    } else if (compareAddress(param.handlerAddress, config.handlers.liquidity)) {
      const handler = LiquidityHandler__factory.connect(param.handlerAddress, deployer);
      await ownerWrapper.authExec(
        handler.address,
        handler.interface.encodeFunctionData("setMinExecutionFee", [param.minExecutionFee])
      );
    } else {
      throw new Error(`Unknown handler address: ${param.handlerAddress}`);
    }
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
