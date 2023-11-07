import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CrossMarginHandler__factory, ERC20__factory, RebalanceHLPv2Service__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);

  const withdrawalParams = [
    {
      market: config.tokens.gmBTCUSD,
      amount: ethers.utils.parseUnits("0.01", 18),
      minLongTokenAmount: 0,
      minShortTokenAmount: 0,
      gasLimit: 1000000,
    },
  ];

  console.log("[cmds/RebalanceHLPv2Service] createWithdrawalOrders...");
  const service = RebalanceHLPv2Service__factory.connect(config.services.rebalanceHLPv2, signer);
  const tx = await service.createWithdrawalOrders(
    withdrawalParams,
    ethers.utils.parseEther("0.001").mul(withdrawalParams.length)
  );
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
