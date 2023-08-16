import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { UniswapDexter__factory } from "../../../../typechain";
import { ethers } from "ethers";

type SetPathConfig = {
  tokenIn: string;
  tokenOut: string;
  path: string;
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const dexter = UniswapDexter__factory.connect(config.extension.dexter.uniswapV3, deployer);

  const txs: Array<SetPathConfig> = [
    {
      tokenIn: config.tokens.arb,
      tokenOut: config.tokens.weth,
      path: ethers.utils.defaultAbiCoder.encode(
        ["address", "uint24", "address"],
        [config.tokens.arb, 500, config.tokens.weth]
      ),
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.arb,
      path: ethers.utils.defaultAbiCoder.encode(
        ["address", "uint24", "address"],
        [config.tokens.weth, 500, config.tokens.arb]
      ),
    },
  ];

  console.log("[UniswapDexter] Setting path config...");
  for (let i = 0; i < txs.length; i++) {
    const tx = await dexter.setPathOf(txs[i].tokenIn, txs[i].tokenOut, txs[i].path, {
      gasLimit: 10000000,
    });
    console.log(`[UniswapDexter] Tx - Set Path of (${txs[i].tokenIn}, ${txs[i].tokenOut}): ${tx.hash}`);
    await tx.wait(1);
  }

  console.log("[UniswapDexter] Finished");
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
