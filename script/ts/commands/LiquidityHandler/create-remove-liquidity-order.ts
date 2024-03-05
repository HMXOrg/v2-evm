import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { LiquidityHandler__factory, ERC20__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const token = ERC20__factory.connect(config.tokens.hlp, signer);

  const tokenOut = config.tokens.usdt!;
  const amountIn = ethers.utils.parseEther("7000");
  const minOut = 0;
  const isNativeOut = false;

  console.log("[LiquidityHandler] createRemoveLiquidityOrder...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, signer);

  // await (await token.approve(handler.address, ethers.constants.MaxUint256)).wait();
  const executionFee = await handler.minExecutionOrderFee();
  const tx = await handler.createRemoveLiquidityOrder(tokenOut, amountIn, minOut, executionFee, isNativeOut, {
    value: executionFee,
  });
  console.log(`[LiquidityHandler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[LiquidityHandler] Finished");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
