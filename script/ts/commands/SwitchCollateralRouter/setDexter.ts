import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { SwitchCollateralRouter__factory } from "../../../../typechain";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const dexter = SwitchCollateralRouter__factory.connect(config.extension.switchCollateralRouter, deployer);
  const tx1 = await dexter.setDexterOf(config.tokens.sglp, config.tokens.weth, config.extension.dexter.glp, {
    gasLimit: 10000000,
  });
  console.log(`[SwitchCollateral] Tx - Set Dexter of (sglp, weth): ${tx1.hash}`);
  await tx1.wait(1);

  const tx2 = await dexter.setDexterOf(config.tokens.weth, config.tokens.sglp, config.extension.dexter.glp, {
    gasLimit: 10000000,
  });
  console.log(`[SwitchCollateral] Tx - Set Dexter of (weth, sglp): ${tx2.hash}`);
  await tx2.wait(1);

  const tx3 = await dexter.setDexterOf(config.tokens.arb, config.tokens.weth, config.extension.dexter.uniswapV3, {
    gasLimit: 10000000,
  });
  console.log(`[SwitchCollateral] Tx - Set Dexter of (arb, weth): ${tx3.hash}`);
  await tx3.wait(1);

  const tx4 = await dexter.setDexterOf(config.tokens.weth, config.tokens.arb, config.extension.dexter.uniswapV3, {
    gasLimit: 10000000,
  });
  console.log(`[SwitchCollateral] Tx - Set Dexter of (weth, arb): ${tx4.hash}`);
  await tx4.wait(1);

  const tx5 = await dexter.setDexterOf(config.tokens.weth, config.tokens.wstEth, config.extension.dexter.curve, {
    gasLimit: 10000000,
  });
  console.log(`[SwitchCollateral] Tx - Set Dexter of (weth, wstEth): ${tx5.hash}`);
  await tx5.wait(1);

  const tx6 = await dexter.setDexterOf(config.tokens.wstEth, config.tokens.weth, config.extension.dexter.curve, {
    gasLimit: 10000000,
  });
  console.log(`[SwitchCollateral] Tx - Set Dexter of (wstEth, weth): ${tx6.hash}`);
  await tx6.wait(1);

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
