import dotenv from "dotenv";

dotenv.config();

export type ChainEntity = {
  name: string;
  rpc: string;
};

if (!process.env.ARBITRUM_MAINNET_RPC) throw new Error("Missing ARBITRUM_MAINNET_RPC env var");

export default {
  42161: {
    name: "arbitrum",
    rpc: process.env.ARBITRUM_MAINNET_RPC,
  },
} as { [chainId: number]: ChainEntity };
