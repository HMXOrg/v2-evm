import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import {
  RebalanceHLPHandler__factory,
  RebalanceHLPv2Handler__factory,
  RebalanceHLPv2Service__factory,
} from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);

  const executionFee = ethers.utils.parseEther("0.002");
  const depositParams = [
    {
      market: config.tokens.gmETHUSD,
      longToken: config.tokens.weth,
      longTokenAmount: ethers.utils.parseUnits("194.63", 18),
      shortToken: config.tokens.usdcNative,
      shortTokenAmount: ethers.utils.parseUnits("0", 6),
      minMarketTokens: 0,
      gasLimit: 1000000,
    },
  ];

  console.log("[cmds/RebalanceHLPv2Service] createDepositOrders...");
  const handler = RebalanceHLPv2Handler__factory.connect(config.handlers.rebalanceHLPv2, signer);
  const value = executionFee.mul(depositParams.length);
  const tx = await handler.createDepositOrders(depositParams, executionFee, { value });
  console.log(`[cmds/RebalanceHLPv2Service] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[cmds/RebalanceHLPv2Service] Finished");
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
