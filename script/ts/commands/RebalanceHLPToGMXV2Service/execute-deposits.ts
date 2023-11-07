import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CrossMarginHandler__factory, ERC20__factory, RebalanceHLPv2Service__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);

  const depositParams = [
    {
      market: config.tokens.gmBTCUSD,
      longToken: config.tokens.wbtc,
      longTokenAmount: ethers.utils.parseUnits("0.01", 8),
      shortToken: config.tokens.usdcCircle,
      shortTokenAmount: 0,
      minMarketTokens: 0,
      executionFee: 0,
    },
  ];

  console.log("[cmds/RebalanceHLPv2Service] depositCollateral...");
  const service = RebalanceHLPv2Service__factory.connect(config.services.rebalanceHLPv2, signer);
  const tx = await service.executeDeposits(depositParams);
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
