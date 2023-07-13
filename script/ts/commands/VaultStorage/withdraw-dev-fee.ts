import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { VaultStorage__factory } from "../../../../typechain";
import MultiCall from "@indexed-finance/multicall";
import chains from "../../entities/chains";
import collaterals from "../../entities/collaterals";
import { ethers } from "ethers";
import * as readlineSync from "readline-sync";
import { TREASURY_ADDRESS } from "../../constants/important-addresses";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const chainInfo = chains[chainId];

  console.log(`[cmds/VaultStorage] Withdraw dev fee to ${TREASURY_ADDRESS}...`);
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, signer);
  const multiCall = new MultiCall(chainInfo.jsonRpcProvider);
  const calls = Object.entries(collaterals).map((c) => ({
    target: config.storages.vault,
    function: "devFees",
    args: [c[1].address],
  }));
  const [, devFees] = await multiCall.multiCall(vaultStorage.interface, calls);
  console.table(
    Object.entries(collaterals).map((c, i) => ({
      symbol: c[0],
      devFee: ethers.utils.formatUnits(devFees[i], c[1].decimals),
    }))
  );
  const confirm = readlineSync.question("Confirm to withdraw dev fee? (y/n): ");
  switch (confirm.toLowerCase()) {
    case "y":
      break;
    case "n":
      console.log("Withdraw dev fee cancelled!");
      return;
    default:
      console.log("Invalid input!");
      return;
  }

  let nonce = await signer.getTransactionCount();
  const txs = await Promise.all(
    Object.entries(collaterals).map((c, i) =>
      vaultStorage.withdrawDevFee(c[1].address, devFees[i], TREASURY_ADDRESS, { nonce: nonce++ })
    )
  );
  console.log("Txs: ", txs.map((tx) => tx.hash).join(", "));
  console.log("[cmds/VaultStorage] Withdraw dev fee success!");
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
