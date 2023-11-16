import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { VaultStorage__factory } from "../../../../typechain";
import { ethers } from "ethers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, signer);

  const amount = 30289413075306806328952;
  const rewarder = "";
  const expiredAt = 1700733600; // Thu Nov 23 2023 10:00:00 GMT+0000

  console.log("[cmds/VaultStorage] createWithdrawalOrders...");
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, signer);
  if (compareAddress(await vaultStorage.owner(), config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      vaultStorage.address,
      0,
      vaultStorage.interface.encodeFunctionData("distributeARBRewardsFromSTIP", [amount, rewarder, expiredAt])
    );
    console.log(`[cmds/VaultStorage] Proposed tx: ${tx}`);
  } else {
    const tx = await vaultStorage.distributeARBRewardsFromSTIP(amount, rewarder, expiredAt);
    console.log(`[cmds/VaultStorage] Tx: ${tx.hash}`);
    await tx.wait();
    console.log(`[cmds/VaultStorage] Finished`);
  }
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
