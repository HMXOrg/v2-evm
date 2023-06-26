import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { JsonRpcProvider } from "@ethersproject/providers";
import { ethers, network } from "hardhat";
import { HttpNetworkUserConfig } from "hardhat/types";

export function isFork() {
  const networkUrl = (network.config as HttpNetworkUserConfig).url;
  if (networkUrl) {
    return networkUrl.indexOf("https://rpc.tenderly.co/fork/") !== -1;
  }
  throw new Error("invalid Network Url");
}

export async function impersonate(to: string): Promise<SignerWithAddress> {
  const [defaultSigner] = await ethers.getSigners();
  console.log("isFOrk", isFork());
  if (isFork()) {
    const provider = ethers.getDefaultProvider((network.config as HttpNetworkUserConfig).url) as JsonRpcProvider;
    const signer = provider.getSigner(to);
    const impersonator = await SignerWithAddress.create(signer);

    return impersonator;
  }

  return defaultSigner;
}
