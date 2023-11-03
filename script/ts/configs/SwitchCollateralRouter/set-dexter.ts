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
  const swithCollateralRouter = SwitchCollateralRouter__factory.connect(
    config.extension.switchCollateralRouter,
    deployer
  );
  const params: Array<SetDexter> = [
    {
      tokenIn: config.tokens.usdc,
      tokenOut: config.tokens.usdcNative,
      dexter: config.extension.dexter.uniswapV3,
    },
    {
      tokenIn: config.tokens.usdcNative,
      tokenOut: config.tokens.usdc,
      dexter: config.extension.dexter.uniswapV3,
    },
  ];

  console.log("[cmds/SwitchCollateralRouter] Setting dexter ...");
  for (let i = 0; i < params.length; i++) {
    const tx = await swithCollateralRouter.setDexterOf(params[i].tokenIn, params[i].tokenOut, params[i].dexter, {
      gasLimit: 10000000,
    });
    console.log(
      `[cmds/SwitchCollateralRouter] Tx - Set Dexter of (${params[i].tokenIn}, ${params[i].tokenOut}): ${tx.hash}`
    );
    await tx.wait(1);
  }
  console.log("[cmds/SwitchCollateralRouter] Finished");
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
