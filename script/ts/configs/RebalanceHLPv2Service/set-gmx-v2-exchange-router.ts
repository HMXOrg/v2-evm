import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import { RebalanceHLPv2Service__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log(`[configs/RebalanceHLPv2Service] setGmxV2ExchangeRouter`);
  const rebalanceHLPv2Service = RebalanceHLPv2Service__factory.connect(config.services.rebalanceHLPv2, deployer);
  await ownerWrapper.authExec(
    rebalanceHLPv2Service.address,
    rebalanceHLPv2Service.interface.encodeFunctionData("setGmxV2ExchangeRouter", [config.vendors.gmxV2.exchangeRouter])
  );
  console.log(`[configs/RebalanceHLPv2Service] Done`);
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
