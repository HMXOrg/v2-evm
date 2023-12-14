import Safe from "@safe-global/safe-core-sdk";
import { EthAdapter, SafeTransactionDataPartial } from "@safe-global/safe-core-sdk-types";
import EthersAdapter from "@safe-global/safe-ethers-lib";
import SafeServiceClient from "@safe-global/safe-service-client";
import { ethers } from "ethers";
import chains from "../../entities/chains";
import { SafeProposeTransactionOptions } from "./type";

export default class SafeWrapper {
  private _safeAddress: string;
  private _ethAdapter: EthAdapter;
  private _safeServiceClient: SafeServiceClient;
  private _signer: ethers.Signer;

  constructor(chainId: number, safeAddress: string, signer: ethers.Signer) {
    const chainInfo = chains[chainId];
    this._safeAddress = safeAddress;
    this._ethAdapter = new EthersAdapter({
      ethers,
      signerOrProvider: signer,
    });
    this._safeServiceClient = new SafeServiceClient({
      txServiceUrl: chainInfo.safeTxServiceUrl,
      ethAdapter: this._ethAdapter,
    });
    this._signer = signer;
  }

  getAddress(): string {
    return this._safeAddress;
  }

  async executePendingTransactions(): Promise<void> {
    const safeSdk = await Safe.create({
      ethAdapter: this._ethAdapter,
      safeAddress: this._safeAddress,
    });

    const pendingTxsResp = await this._safeServiceClient.getPendingTransactions(this._safeAddress);
    let pendingTxs = pendingTxsResp.results.length - 1;
    let executedTx = 1;
    for (let i = pendingTxsResp.results.length - 1; i >= 0; i--) {
      console.log(
        `[SafeWrapper/executePendingTransactions][${executedTx++}/${pendingTxs}] Executing tx ${
          pendingTxsResp.results[i].safeTxHash
        }`
      );
      await safeSdk.executeTransaction(pendingTxsResp.results[i]);
    }
  }

  async proposeTransaction(
    to: string,
    value: ethers.BigNumberish,
    data: string,
    opts?: SafeProposeTransactionOptions
  ): Promise<string> {
    const safeSdk = await Safe.create({
      ethAdapter: this._ethAdapter,
      safeAddress: this._safeAddress,
    });

    let whichNonce = 0;
    if (opts) {
      // Handling nonce
      if (opts.nonce) {
        // If options has nonce, use it
        whichNonce = opts.nonce;
      } else {
        // If options has no nonce, get next nonce from safe service
        whichNonce = await this._safeServiceClient.getNextNonce(this._safeAddress);
      }
    } else {
      // If options is undefined, get next nonce from safe service
      whichNonce = await this._safeServiceClient.getNextNonce(this._safeAddress);
    }

    const safeTransactionData: SafeTransactionDataPartial = {
      to,
      value: value.toString(),
      data,
      nonce: whichNonce,
    };

    const safeTransaction = await safeSdk.createTransaction({
      safeTransactionData,
    });
    const senderAddress = await this._signer.getAddress();
    const safeTxHash = await safeSdk.getTransactionHash(safeTransaction);
    const signature = await safeSdk.signTransactionHash(safeTxHash);

    await this._safeServiceClient.proposeTransaction({
      safeAddress: this._safeAddress,
      safeTransactionData: safeTransaction.data,
      safeTxHash,
      senderAddress,
      senderSignature: signature.data,
    });

    return safeTxHash;
  }
}
