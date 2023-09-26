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
      tokenOut: config.tokens.usdc,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.usdt, 500, config.tokens.usdc]),
    },
    {
      tokenIn: config.tokens.usdc,
      tokenOut: config.tokens.usdt,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.usdc, 500, config.tokens.usdt]),
    },
    {
      tokenIn: config.tokens.dai,
      tokenOut: config.tokens.usdc,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.dai, 500, config.tokens.usdc]),
    },
    {
      tokenIn: config.tokens.usdc,
      tokenOut: config.tokens.dai,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.usdc, 500, config.tokens.dai]),
    },
    {
      tokenIn: config.tokens.dai,
      tokenOut: config.tokens.usdt,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.dai, 500, config.tokens.usdt]),
    },
    {
      tokenIn: config.tokens.usdt,
      tokenOut: config.tokens.dai,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.usdt, 500, config.tokens.dai]),
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.usdc,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.weth, 500, config.tokens.usdc]),
    },
    {
      tokenIn: config.tokens.usdc,
      tokenOut: config.tokens.weth,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.usdc, 500, config.tokens.weth]),
    },
    {
      tokenIn: config.tokens.wbtc,
      tokenOut: config.tokens.usdc,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.wbtc, 3000, config.tokens.usdc]),
    },
    {
      tokenIn: config.tokens.usdc,
      tokenOut: config.tokens.wbtc,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.usdc, 3000, config.tokens.wbtc]),
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.arb,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.weth, 3000, config.tokens.arb]),
    },
    {
      tokenIn: config.tokens.arb,
      tokenOut: config.tokens.weth,
      path: ethers.utils.solidityPack(["address", "uint24", "address"], [config.tokens.arb, 3000, config.tokens.weth]),
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.sglp,
      path: ethers.utils.solidityPack(
        ["address", "uint24", "address"],
        [config.tokens.weth, 10000, config.tokens.sglp]
      ),
    },
    {
      tokenIn: config.tokens.sglp,
      tokenOut: config.tokens.weth,
      path: ethers.utils.solidityPack(
        ["address", "uint24", "address"],
        [config.tokens.sglp, 10000, config.tokens.weth]
      ),
    },
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.wstEth,
      path: ethers.utils.solidityPack(
        ["address", "uint24", "address"],
        [config.tokens.weth, 500, config.tokens.wstEth]
      ),
    },
    {
      tokenIn: config.tokens.wstEth,
      tokenOut: config.tokens.weth,
      path: ethers.utils.solidityPack(
        ["address", "uint24", "address"],
        [config.tokens.wstEth, 500, config.tokens.weth]
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
