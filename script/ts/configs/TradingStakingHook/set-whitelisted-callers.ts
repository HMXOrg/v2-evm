import { TradingStakingHook__factory } from "../../../../typechain";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, deployer);

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

  const tradingStakingHook = TradingStakingHook__factory.connect(config.hooks.tlc, deployer);
  const owner = await tradingStakingHook.owner();
  console.log(`[configs/TradingStakingHook] Set Whitelisted Callers`);
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      tradingStakingHook.address,
      0,
      tradingStakingHook.interface.encodeFunctionData("setWhitelistedCallers", [
        whitelistedCallers.map((each) => each.caller),
        whitelistedCallers.map((each) => each.isWhitelisted),
      ])
    );
    console.log(`[configs/TradingStakingHook] Proposed tx: ${tx}`);
  } else {
    const tx = await tradingStakingHook.setWhitelistedCallers(
      whitelistedCallers.map((each) => each.caller),
      whitelistedCallers.map((each) => each.isWhitelisted)
    );
    console.log(`[configs/TradingStakingHook] Tx: ${tx}`);
    await tx.wait();
  }
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
