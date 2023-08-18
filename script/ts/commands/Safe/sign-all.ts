import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import chains from "../../entities/chains";
import { ethers } from "ethers";
import SafeApiKit from "@safe-global/api-kit";
import { EthersAdapter } from "@safe-global/protocol-kit";
import Safe from "@safe-global/protocol-kit";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const chainInfo = chains[chainId];

  const ethAdapter = new EthersAdapter({
    ethers,
    signerOrProvider: signer,
  });
  const safeService = new SafeApiKit({
    txServiceUrl: "https://safe-transaction-arbitrum.safe.global/",
    ethAdapter,
  });
  const safeSdk = await Safe.create({ ethAdapter, safeAddress: config.safe });

  const allTxs = await safeService.getPendingTransactions(config.safe);
  console.log(allTxs);
  for (let tx of allTxs.results) {
    console.log(`Confirming Nonce: #${tx.nonce}`);
    const hash = tx.safeTxHash;
    let signature = await safeSdk.signTransactionHash(hash);
    try {
      const response = await safeService.confirmTransaction(hash, signature.data);
    } catch (e) {
      console.log(e);
    }
    console.log("Done");
  }
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
