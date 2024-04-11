import dotenv from "dotenv";
import { ethers } from "ethers";

dotenv.config();

export type ChainEntity = {
  name: string;
  rpc: string;
  jsonRpcProvider: ethers.providers.JsonRpcProvider;
  safeTxServiceUrl: string;
  statSubgraphUrl: string;
};

if (!process.env.ARBITRUM_MAINNET_RPC) throw new Error("Missing ARBITRUM_MAINNET_RPC env var");
if (!process.env.ARBI_STAT_SUBGRAPH_URL) throw new Error("Missing ARBI_STAT_SUBGRAPH_URL env var");

export default {
  8453: {
    name: "base",
    rpc: process.env.BASE_MAINNET_RPC,
    jsonRpcProvider: new ethers.providers.JsonRpcProvider(process.env.BASE_MAINNET_RPC),
    safeTxServiceUrl: "https://safe-transaction-arbitrum.safe.global/",
    statSubgraphUrl: process.env.ARBI_STAT_SUBGRAPH_URL,
  },
  84532: {
    name: "base_sepolia",
    rpc: process.env.BASE_SEPOLIA_RPC,
    jsonRpcProvider: new ethers.providers.JsonRpcProvider(process.env.BASE_SEPOLIA_RPC),
    safeTxServiceUrl: "https://safe-transaction-arbitrum.safe.global/",
    statSubgraphUrl: "",
  },
} as { [chainId: number]: ChainEntity };
