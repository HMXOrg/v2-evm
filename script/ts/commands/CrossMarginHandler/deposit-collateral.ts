import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CrossMarginHandler__factory, ERC20__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);

  const tokenAddress = config.tokens.usdt!;
  const amountIn = ethers.utils.parseUnits("500", 6);
  const subAccountId = 0;
  const shouldWrap = false;

  console.log("[CrossMarginHandler] depositCollateral...");
  const handler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, signer);
  const token = ERC20__factory.connect(tokenAddress, signer);
  await (await token.approve(handler.address, amountIn)).wait();
  const tx = await handler.depositCollateral(subAccountId, tokenAddress, amountIn, shouldWrap);
  console.log(`[CrossMarginHandler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[CrossMarginHandler] Finished");
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
