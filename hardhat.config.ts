import { config as dotEnvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import fs from "fs";
dotEnvConfig();

import * as tdly from "@tenderly/hardhat-tenderly";
tdly.setup({ automaticVerifications: false });

import "@openzeppelin/hardhat-upgrades";
import "hardhat-preprocessor";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.trim().split("="));
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    matic: {
      url: process.env.POLYGON_MAINNET_RPC || "",
      accounts: process.env.POLYGON_MAINNET_PRIVATE_KEY !== undefined ? [process.env.POLYGON_MAINNET_PRIVATE_KEY] : [],
    },
    mumbai: {
      url: process.env.POLYGON_MUMBAI_RPC || "",
      accounts: process.env.POLYGON_MUMBAI_PRIVATE_KEY !== undefined ? [process.env.POLYGON_MUMBAI_PRIVATE_KEY] : [],
    },
    tenderly: {
      url: process.env.POLYGON_TENDERLY_RPC || "",
      accounts:
        process.env.POLYGON_MAINNET_PRIVATE_KEY !== undefined
          ? [process.env.POLYGON_MAINNET_PRIVATE_KEY, process.env.POSITION_MANAGER_PRIVATE_KEY!]
          : [],
    },
    arb_goerli: {
      url: process.env.ARBITRUM_GOERLI_RPC || "",
      chainId: 421613,
      accounts:
        process.env.POLYGON_MAINNET_PRIVATE_KEY !== undefined
          ? [process.env.POLYGON_MAINNET_PRIVATE_KEY, process.env.POSITION_MANAGER_PRIVATE_KEY!]
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
    cache: "./cache_hardhat",
    artifacts: "./artifacts",
  },
  typechain: {
    outDir: "./typechain",
    target: "ethers-v5",
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT_NAME!,
    username: process.env.TENDERLY_USERNAME!,
    privateVerification: true,
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
};

export default config;
