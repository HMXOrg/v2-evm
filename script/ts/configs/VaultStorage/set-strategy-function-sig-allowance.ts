import { ERC20__factory, IRewarder__factory, VaultStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const token = config.tokens.arb;
  const strategy = config.strategies.distributeSTIPARB;
  const sig = IRewarder__factory.createInterface().getSighash("feedWithExpiredAt(uint256,uint256)");

  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);
  console.log(`[configs/VaultStorage] setStrategyFunctionSigAllowance`);
  await ownerWrapper.authExec(
    vaultStorage.address,
    vaultStorage.interface.encodeFunctionData("setStrategyFunctionSigAllowance", [token, strategy, sig])
  );
  console.log("[configs/VaultStorage] Done");
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
