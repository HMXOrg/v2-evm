import {
  DistributeSTIPARBStrategy__factory,
  ERC20__factory,
  IRewarder__factory,
  VaultStorage__factory,
} from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);

  const token = config.tokens.arb;
  const strategy = config.strategies.erc20Approve;
  const sig = ERC20__factory.createInterface().getSighash("approve(address,uint256)");

  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);
  const owner = await vaultStorage.owner();
  console.log(`[configs/VaultStorage] setStrategyFunctionSigAllowance`);
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      vaultStorage.address,
      0,
      vaultStorage.interface.encodeFunctionData("setStrategyFunctionSigAllowance", [token, strategy, sig])
    );
    console.log(`[configs/VaultStorage] Proposed tx: ${tx}`);
  } else {
    const tx = await vaultStorage.setStrategyFunctionSigAllowance(token, strategy, sig);
    console.log(`[configs/VaultStorage] Tx: ${tx}`);
    await tx.wait();
  }
  console.log("[configs/VaultStorage] Finished");
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
