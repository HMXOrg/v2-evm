import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { LiquidityHandler__factory, ERC20__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);

  const tokenAddress = config.tokens.usdc;
  const amountIn = ethers.utils.parseUnits("10000", 6);
  const minOut = 0;
  const shouldWrap = false;

  console.log("[LiquidityHandler] createAddLiquidityOrder...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, signer);
  const token = ERC20__factory.connect(tokenAddress, signer);
  await token.approve(handler.address, amountIn);
  const executionFee = await handler.minExecutionOrderFee();
  const tx = await handler["createAddLiquidityOrder(address,uint256,uint256,uint256,bool)"](
    tokenAddress,
    amountIn,
    minOut,
    await handler.minExecutionOrderFee(),
    shouldWrap,
    { value: executionFee }
  );
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
