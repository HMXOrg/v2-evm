import { network } from "hardhat";
import * as fs from "fs";
import ArbitrumGoerliConfig from "../../configs/arbitrum.goerli.json";
import ArbitrumMainnetConfig from "../../configs/arbitrum.mainnet.json";

export function getConfig() {
  if (network.name === "matic") {
    return ArbitrumGoerliConfig;
  }
  if (network.name === "tenderly") {
    return ArbitrumMainnetConfig;
  }
  if (network.name === "mumbai") {
    return ArbitrumGoerliConfig;
  }
  if (network.name === "arb_goerli") {
    return ArbitrumGoerliConfig;
  }

  throw new Error("not found config");
}

export function writeConfigFile(config: any) {
  let filePath;
  switch (network.name) {
    case "matic":
      filePath = "./configs/arbitrum.goerli.json";
      break;
    case "tenderly":
      filePath = "./configs/arbitrum.mainnet.json";
      break;
    case "mumbai":
      filePath = "./configs/arbitrum.goerli.json";
      break;
    case "arb_goerli":
      filePath = "./configs/arbitrum.goerli.json";
      break;
    default:
      throw Error("Unsupported network");
  }
  console.log(`> Writing ${filePath}`);
  fs.writeFileSync(filePath, JSON.stringify(config, null, 2));
  console.log("> ✅ Done");
}
