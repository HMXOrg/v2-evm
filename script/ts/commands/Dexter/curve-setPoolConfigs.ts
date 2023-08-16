import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CurveDexter__factory } from "../../../../typechain";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const dexter = CurveDexter__factory.connect(config.extension.dexter.curve, deployer);
  const tx1 = await dexter.setPoolConfigOf(
    config.tokens.weth,
    config.tokens.wstEth,
    config.extension.curveWstEthPool,
    0,
    1,
    {
      gasLimit: 10000000,
    }
  );
  console.log(`[CurveDexter] Tx - Set Pool Config of (WETH, WSTETH): ${tx1.hash}`);
  await tx1.wait(1);
  const tx2 = await dexter.setPoolConfigOf(
    config.tokens.wstEth,
    config.tokens.weth,
    config.extension.curveWstEthPool,
    1,
    0,
    {
      gasLimit: 10000000,
    }
  );
  console.log(`[CurveDexter] Tx - Set Pool Config of (WSTETH, WETH): ${tx2.hash}`);
  await tx2.wait(1);
  console.log("[CurveDexter] Finished");
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
