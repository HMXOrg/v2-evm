import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { SwitchCollateralRouter__factory } from "../../../../typechain";

type SetDexter = {
  tokenIn: string;
  tokenOut: string;
  dexter: string;
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const dexter = SwitchCollateralRouter__factory.connect(config.extension.switchCollateralRouter, deployer);
  const txs: Array<SetDexter> = [
    {
      tokenIn: config.tokens.sglp,
      tokenOut: config.tokens.weth,
      dexter: config.extension.dexter.glp,
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.sglp,
      dexter: config.extension.dexter.glp,
    },
    {
      tokenIn: config.tokens.arb,
      tokenOut: config.tokens.weth,
      dexter: config.extension.dexter.uniswapV3,
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.arb,
      dexter: config.extension.dexter.uniswapV3,
    },
    {
      tokenIn: config.tokens.wstEth,
      tokenOut: config.tokens.weth,
      dexter: config.extension.dexter.curve,
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.wstEth,
      dexter: config.extension.dexter.curve,
    },
  ];

  console.log("[SwitchCollateral] Setting dexter ...");
  for (let i = 0; i < txs.length; i++) {
    const tx = await dexter.setDexterOf(txs[i].tokenIn, txs[i].tokenOut, txs[i].dexter, {
      gasLimit: 10000000,
    });
    console.log(`[SwitchCollateral] Tx - Set Dexter of (${txs[i].tokenIn}, ${txs[i].tokenOut}): ${tx.hash}`);
    await tx.wait(1);
  }
  console.log("[SwitchCollateralRouter] Finished");
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
