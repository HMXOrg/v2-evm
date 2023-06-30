import dotenv from "dotenv";
import { ethers } from "ethers";

dotenv.config();

export type ChainEntity = {
  name: string;
  rpc: string;
  jsonRpcProvider: ethers.providers.JsonRpcProvider;
};

if (!process.env.ARBITRUM_MAINNET_RPC) throw new Error("Missing ARBITRUM_MAINNET_RPC env var");

export default {
  42161: {
    name: "arbitrum",
    rpc: process.env.ARBITRUM_MAINNET_RPC,
    jsonRpcProvider: new ethers.providers.JsonRpcProvider(process.env.ARBITRUM_MAINNET_RPC),
  },
  421613: {
    name: "arbitrum",
    rpc: process.env.ARBITRUM_GOERLI_RPC,
    jsonRpcProvider: new ethers.providers.JsonRpcProvider(process.env.ARBITRUM_GOERLI_RPC),
  },
} as { [chainId: number]: ChainEntity };
