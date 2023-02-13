import { config as dotEnvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
dotEnvConfig();

import * as tdly from "@tenderly/hardhat-tenderly";
tdly.setup({ automaticVerifications: false });

import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-deploy";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    matic: {
      url: process.env.POLYGON_MAINNET_RPC,
      accounts:
        process.env.POLYGON_MAINNET_PRIVATE_KEY !== undefined
          ? [process.env.POLYGON_MAINNET_PRIVATE_KEY]
          : [],
    },
    mumbai: {
      url: process.env.POLYGON_MUMBAI_RPC,
      accounts:
        process.env.POLYGON_MUMBAI_PRIVATE_KEY !== undefined
          ? [process.env.POLYGON_MUMBAI_PRIVATE_KEY]
          : [],
    },
    tenderly: {
      url: process.env.POLYGON_TENDERLY_RPC,
      accounts:
        process.env.POLYGON_MAINNET_PRIVATE_KEY !== undefined
          ? [process.env.POLYGON_MAINNET_PRIVATE_KEY]
          : [],
    },
  },
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  paths: {
    sources: "./src",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  typechain: {
    outDir: "./typechain",
    target: "ethers-v5",
  },
  mocha: {
    timeout: 100000,
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT_NAME!,
    username: process.env.TENDERLY_USERNAME!,
    privateVerification: true,
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
};

export default config;
