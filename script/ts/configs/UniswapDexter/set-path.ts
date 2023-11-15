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

  const params: Array<SetPathConfig> = [
    {
      tokenIn: config.tokens.usdt,
      tokenOut: config.tokens.usdcNative,
      path: ethers.utils.solidityPack(
        ["address", "uint24", "address"],
        [config.tokens.usdt, 100, config.tokens.usdcNative]
      ),
    },
  ];

  console.log("[cmds/UniswapDexter] Setting path config...");
  for (let i = 0; i < params.length; i++) {
    console.log(params[i].path);
    const tx = await dexter.setPathOf(params[i].tokenIn, params[i].tokenOut, params[i].path, {
      gasLimit: 10000000,
    });
    console.log(`[cmds/UniswapDexter] Tx - Set Path of (${params[i].tokenIn}, ${params[i].tokenOut}): ${tx.hash}`);
    await tx.wait(1);
  }

  console.log("[cmds/UniswapDexter] Finished");
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
