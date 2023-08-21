import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CurveDexter__factory } from "../../../../typechain";

type SetPoolConfig = {
  tokenIn: string;
  tokenOut: string;
  pool: string;
  fromIndex: number;
  toIndex: number;
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const dexter = CurveDexter__factory.connect(config.extension.dexter.curve, deployer);

  const params: Array<SetPoolConfig> = [
    {
      tokenIn: config.tokens.usdc,
      tokenOut: config.tokens.usdt,
      pool: config.vendors.curve.usdcUsdtPool,
      fromIndex: 0,
      toIndex: 1,
    },
    {
      tokenIn: config.tokens.usdt,
      tokenOut: config.tokens.usdc,
      pool: config.vendors.curve.usdcUsdtPool,
      fromIndex: 1,
      toIndex: 0,
    },
  ];

  console.log("[configs/CurveDexter] Setting pool config...");
  for (let i = 0; i < params.length; i++) {
    const tx = await dexter.setPoolConfigOf(
      params[i].tokenIn,
      params[i].tokenOut,
      params[i].pool,
      params[i].fromIndex,
      params[i].toIndex
    );
    console.log(
      `[configs/CurveDexter] Tx - Set Pool Config of (${params[i].tokenIn}, ${params[i].tokenOut}): ${tx.hash}`
    );
    await tx.wait(1);
  }
  console.log("[configs/CurveDexter] Finished");
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
