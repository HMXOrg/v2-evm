import { ethers } from "ethers";
import { abi as ProxyAdminAbi } from "../../../../abis/ProxyAdmin.json";
import SafeWrapper from "../SafeWrapper";
import TimelockWrapper from "../TimelockWrapper";
import { loadConfig } from "../../utils/config";
import { compareAddress } from "../../utils/address";

export default class {
  proxyAdmin: ethers.Contract;
  timelockWrapper: TimelockWrapper;
  safeWrapper: SafeWrapper;
  signer: ethers.Signer;

  constructor(chainId: number, signer: ethers.Signer) {
    const config = loadConfig(chainId);
    this.proxyAdmin = new ethers.Contract(config.proxyAdmin, ProxyAdminAbi, signer);
    this.timelockWrapper = new TimelockWrapper(chainId, signer);
    this.safeWrapper = new SafeWrapper(chainId, config.safe, signer);
    this.signer = signer;
  }

  async upgrade(proxyAddress: string, implementationAddress: string) {
    const owner = await this.proxyAdmin.owner();
    console.log("owner", owner);
    const signer = await this.signer.getAddress();
    console.log("signer", signer);
    const timelockOwner = this.timelockWrapper.getAddress();
    console.log("timelockOwner", timelockOwner);

    if (compareAddress(owner, this.safeWrapper.getAddress())) {
      // Safe is the owner of the ProxyAdmin
      console.log(`[wrapper/PrpxyAdmin] Safe is the owner of the ProxyAdmin`);
      console.log(`[wrapper/ProxyAdmin] Proposing upgrade of ${proxyAddress} to ${implementationAddress}`);
      await this.safeWrapper.proposeTransaction(
        this.proxyAdmin.address,
        0,
        this.proxyAdmin.interface.encodeFunctionData("upgrade", [proxyAddress, implementationAddress])
      );
      console.log(`[wrapper/ProxyAdmin] Done`);
    } else if (compareAddress(owner, timelockOwner)) {
      console.log(`[wrapper/PrpxyAdmin] Timelock is the owner of the ProxyAdmin`);
      console.log(`[wrapper/ProxyAdmin] Queueing upgrade of ${proxyAddress} to ${implementationAddress}`);
      // Timelock is the owner of the ProxyAdmin
      const minimumDelay = await this.timelockWrapper.minimumDelay();
      // Add 15 minutes to the current timestamp + minimumDelay
      const eta = Math.floor(Date.now() / 1000) + Number(minimumDelay.toString()) + 900;
      await this.timelockWrapper.queueTransaction(
        "Upgrade Proxy",
        this.proxyAdmin.address,
        0,
        "upgrade(address,address)",
        ["address", "address"],
        [proxyAddress, implementationAddress],
        eta
      );
      console.log(`[wrapper/ProxyAdmin] Done`);
    } else if (compareAddress(owner, signer)) {
      // Signer is the owner of the ProxyAdmin
      console.log(`[wrapper/PrpxyAdmin] Signer is the owner of the ProxyAdmin`);
      console.log(`[wrapper/ProxyAdmin] Upgrading ${proxyAddress} to ${implementationAddress}`);
      await this.proxyAdmin.upgrade(proxyAddress, implementationAddress);
      console.log(`[wrapper/ProxyAdmin] Done`);
    } else {
      throw new Error("ProxyAdmin is not owned by Safe or Timelock");
    }
  }
}
