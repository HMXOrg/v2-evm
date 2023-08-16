import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { UniswapDexter__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const dexter = UniswapDexter__factory.connect(config.extension.dexter.uniswapV3, deployer);
  const tx1 = await dexter.setPathOf(
    config.tokens.arb,
    config.tokens.weth,
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [config.tokens.arb, 500, config.tokens.weth]),
    {
      gasLimit: 10000000,
    }
  );
  console.log(`[UniswapDexter] Tx - Set Path of (ARB, WETH): ${tx1.hash}`);
  await tx1.wait(1);
  const tx2 = await dexter.setPathOf(
    config.tokens.weth,
    config.tokens.arb,
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [config.tokens.weth, 500, config.tokens.arb]),
    {
      gasLimit: 10000000,
    }
  );
  console.log(`[UniswapDexter] Tx - Set Path of (WETH, ARB): ${tx2.hash}`);
  await tx2.wait(1);
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
