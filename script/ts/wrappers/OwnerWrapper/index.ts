import { ethers } from "ethers";
import SafeWrapper from "../SafeWrapper";
import TimelockWrapper from "../TimelockWrapper";
import { OwnableUpgradeable__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";

export class OwnerWrapper {
  timelockWrapper: TimelockWrapper;
  safeWrapper: SafeWrapper;
  signer: ethers.Signer;

  constructor(chainId: number, signer: ethers.Signer) {
    const config = loadConfig(chainId);
    this.timelockWrapper = new TimelockWrapper(chainId, signer);
    this.safeWrapper = new SafeWrapper(chainId, config.safe, signer);
    this.signer = signer;
  }

  async authExec(to: string, data: string, msgValue?: ethers.BigNumberish) {
    const ownable = OwnableUpgradeable__factory.connect(to, this.signer);
    const owner = await ownable.owner();
    const signerAddress = await this.signer.getAddress();
    const timelockAddress = this.timelockWrapper.getAddress();
    const safeWrapperAddress = this.safeWrapper.getAddress();

    if (msgValue == undefined) {
      msgValue = 0;
    }

    if (owner === signerAddress) {
      console.log(`[wrapper/Owner] Signer is the owner of ${to}`);
      console.log(`[wrapper/Owner] Executing tx right away...`);
      const tx = await this.signer.sendTransaction({ to, data, value: msgValue });
      console.log(`[wrapper/Owner] Tx: ${tx.hash}`);
    } else if (owner === timelockAddress) {
      throw new Error("Not implemented when owner is Timelock yet");
    } else if (owner === safeWrapperAddress) {
      console.log(`[wrapper/Owner] Safe is the owner of ${to}`);
      console.log(`[wrapper/Owner] Proposing tx...`);
      const tx = await this.safeWrapper.proposeTransaction(to, msgValue, data);
      console.log(`[wrapper/Owner] Tx: ${tx}`);
    } else {
      throw new Error("Unknown owner");
    }
  }
}
