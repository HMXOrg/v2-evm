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

  const txs: Array<SetPoolConfig> = [
    {
      tokenIn: config.tokens.weth,
      tokenOut: config.tokens.wstEth,
      pool: config.vendors.curve.wstEthPool,
      fromIndex: 0,
      toIndex: 1,
    },
    {
      tokenIn: config.tokens.wstEth,
      tokenOut: config.tokens.weth,
      pool: config.vendors.curve.wstEthPool,
      fromIndex: 1,
      toIndex: 0,
    },
  ];

  console.log("[CurveDexter] Setting pool config...");
  for (let i = 0; i < txs.length; i++) {
    const tx = await dexter.setPoolConfigOf(
      txs[i].tokenIn,
      txs[i].tokenOut,
      txs[i].pool,
      txs[i].fromIndex,
      txs[i].toIndex,
      {
        gasLimit: 10000000,
      }
    );
    console.log(`[CurveDexter] Tx - Set Pool Config of (${txs[i].tokenIn}, ${txs[i].tokenOut}): ${tx.hash}`);
    await tx.wait(1);
  }
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
