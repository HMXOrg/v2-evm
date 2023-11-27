import { ethers } from "ethers";
import SafeWrapper from "../SafeWrapper";
import { loadConfig } from "../../utils/config";
import { abi as TimelockAbi } from "../../../../abis/Timelock.json";
import { compareAddress } from "../../utils/address";
import { TimelockWrapperTransaction } from "./type";
import chains from "../../entities/chains";

export default class TimelockWrapper {
  private chainId: number;
  private timelock: ethers.Contract;
  private safe: SafeWrapper;
  private signer: ethers.Signer;
  private forkMode: boolean;

  constructor(_chainId: number, _signer: ethers.Signer, _forkMode?: boolean) {
    const config = loadConfig(_chainId);

    this.chainId = _chainId;
    this.timelock = new ethers.Contract(config.timelock, TimelockAbi, _signer);
    this.safe = new SafeWrapper(this.chainId, config.safe, _signer);
    this.signer = _signer;
    this.forkMode = _forkMode || false;
  }

  getAddress(): string {
    return this.timelock.address;
  }

  async owner(): Promise<string> {
    return await this.timelock.admin();
  }

  async minimumDelay(): Promise<ethers.BigNumber> {
    return await this.timelock.MINIMUM_DELAY();
  }

  interface(): ethers.utils.Interface {
    return this.timelock.interface;
  }

  async queueTransaction(
    info: string,
    target: string,
    value: ethers.BigNumberish,
    signature: string,
    paramTypes: Array<string>,
    params: Array<any>,
    eta: ethers.BigNumberish,
    overrides?: ethers.Overrides
  ): Promise<TimelockWrapperTransaction> {
    const etaBN = ethers.BigNumber.from(eta);
    const signerAddress = await this.signer.getAddress();
    const timelockAdmin = await this.timelock.admin();

    let txHash = "";
    if (compareAddress(timelockAdmin, signerAddress)) {
      console.log(`[wrapper/TimelockWrapper] Queue tx for: ${info}`);
      const queueTx = await this.timelock.queueTransaction(
        target,
        value,
        signature,
        ethers.utils.defaultAbiCoder.encode(paramTypes, params),
        eta,
        overrides
      );
      await queueTx.wait();
      txHash = queueTx.hash;
    } else if (compareAddress(timelockAdmin, this.safe.getAddress())) {
      if (!this.forkMode) {
        console.log(`[wrapper/TimelockWrapper] Propose tx for: ${info}`);
        info = `MultiSign: ${info}`;
        txHash = await this.safe.proposeTransaction(
          this.timelock.address,
          "0",
          this.timelock.interface.encodeFunctionData("queueTransaction", [
            target,
            value,
            signature,
            ethers.utils.defaultAbiCoder.encode(paramTypes, params),
            eta,
          ])
        );
      } else {
        console.log(`[wrapper/TimelockWrapper] 🍴 Fork mode is ON, skip proposing tx and queue directly as multisig`);
        const jsonRpcProvider = chains[this.chainId].jsonRpcProvider;
        const multiSigAsSigner = jsonRpcProvider.getSigner(this.safe.getAddress());
        const timelockAsMultiSig = new ethers.Contract(this.timelock.address, TimelockAbi, multiSigAsSigner);
        txHash = (
          await timelockAsMultiSig.queueTransaction(
            target,
            value,
            signature,
            ethers.utils.defaultAbiCoder.encode(paramTypes, params),
            eta
          )
        ).hash;
      }
    } else {
      throw new Error("MaybeMultisigTimelock: Unknown admin");
    }
    const paramTypesStr = paramTypes.map((p) => `'${p}'`);
    const paramsStr = params.map((p) => {
      if (Array.isArray(p)) {
        const vauleWithQuote = p.map((p) => {
          if (typeof p === "string") return `'${p}'`;
          return JSON.stringify(p);
        });
        return `[${vauleWithQuote}]`;
      }

      if (typeof p === "string") {
        return `'${p}'`;
      }

      return p;
    });

    const executionTx = `await timelock.executeTransaction('${target}', '${value}', '${signature}', ethers.utils.defaultAbiCoder.encode([${paramTypesStr}], [${paramsStr}]), '${eta}')`;
    console.log(`[wrapper/TimelockWrapper] ⛓ Queued at: ${txHash}`);
    return {
      info: info,
      chainId: this.chainId,
      queuedAt: txHash,
      executedAt: "",
      executionTransaction: executionTx,
      target,
      value: ethers.BigNumber.from(value).toString(),
      signature,
      paramTypes,
      params,
      eta: etaBN.toString(),
    };
  }

  async executeTransaction(
    info: string,
    queuedAt: string,
    executionTx: string,
    target: string,
    value: ethers.BigNumberish,
    signature: string,
    paramTypes: Array<string>,
    params: Array<any>,
    eta: ethers.BigNumberish,
    overrides?: ethers.Overrides
  ): Promise<TimelockWrapperTransaction> {
    console.log(`[wrapper/TimelockWrapper] Execute tx for: ${info}`);
    const etaBN = ethers.BigNumber.from(eta);
    const signerAddress = await this.signer.getAddress();
    const timelockAdmin = await this.timelock.admin();

    let txHash = "";
    if (compareAddress(timelockAdmin, signerAddress)) {
      const queueTx = await this.timelock.executeTransaction(
        target,
        value,
        signature,
        ethers.utils.defaultAbiCoder.encode(paramTypes, params),
        etaBN,
        overrides
      );
      await queueTx.wait();
      txHash = queueTx.hash;
      console.log("[wrapper/TimelockWrapper] ⛓ Executed at:", txHash);
    } else if (compareAddress(timelockAdmin, this.safe.getAddress())) {
      if (!this.forkMode) {
        txHash = await this.safe.proposeTransaction(
          this.timelock.address,
          "0",
          this.timelock.interface.encodeFunctionData("executeTransaction", [
            target,
            value,
            signature,
            ethers.utils.defaultAbiCoder.encode(paramTypes, params),
            eta,
          ])
        );
        console.log("[wrapper/TimelockWrapper] Proposed at:", txHash);
      } else {
        console.log(`[wrapper/TimelockWrapper] 🍴 Fork mode is ON, skip proposing tx and execute directly as multisig`);
        const jsonRpcProvider = chains[this.chainId].jsonRpcProvider;
        const multiSigAsSigner = jsonRpcProvider.getSigner(this.safe.getAddress());
        const timelockAsMultiSig = new ethers.Contract(this.timelock.address, TimelockAbi, multiSigAsSigner);
        txHash = (
          await timelockAsMultiSig.executeTransaction(
            target,
            value,
            signature,
            ethers.utils.defaultAbiCoder.encode(paramTypes, params),
            eta
          )
        ).hash;
      }
    }
    console.log(`[wrapper/TimelockWrapper] Done.`);

    return {
      info: info,
      chainId: this.chainId,
      queuedAt: queuedAt,
      executedAt: txHash,
      executionTransaction: executionTx,
      target,
      value: ethers.BigNumber.from(value).toString(),
      signature,
      paramTypes,
      params,
      eta: etaBN.toString(),
    };
  }
}
