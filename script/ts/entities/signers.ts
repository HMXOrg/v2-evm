import { ethers } from "ethers";
import dotenv from "dotenv";
import chains from "./chains";

dotenv.config();

export default {
  deployer: (chainId: number): ethers.Signer => {
    if (!process.env.ARBI_MAINNET_PRIVATE_KEY) throw new Error("Missing ARBI_MAINNET_PRIVATE_KEY env var");
    return new ethers.Wallet(process.env.ARBI_MAINNET_PRIVATE_KEY, chains[chainId].jsonRpcProvider);
  },
};
