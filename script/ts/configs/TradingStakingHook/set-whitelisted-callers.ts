import { TradingStakingHook__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const whitelistedCallers = [
    {
      caller: config.services.trade,
      isWhitelisted: true,
    },
    {
      caller: config.services.liquidation,
      isWhitelisted: true,
    },
  ];

  const tradingStakingHook = TradingStakingHook__factory.connect(config.hooks.tradingStaking, deployer);
  console.log(`[configs/TradingStakingHook] Set Whitelisted Callers`);
  await ownerWrapper.authExec(
    tradingStakingHook.address,
    tradingStakingHook.interface.encodeFunctionData("setWhitelistedCallers", [
      whitelistedCallers.map((each) => each.caller),
      whitelistedCallers.map((each) => each.isWhitelisted),
    ])
  );
  console.log("[configs/TradingStakingHook] Finished");
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
