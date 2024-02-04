import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { ConfigStorage__factory } from "../../../typechain";
import { getConfig } from "../utils/config";
import { MultiCall } from "@indexed-finance/multicall";
import { strict as assert } from "assert";

const { formatUnits, parseUnits } = ethers.utils;

const config = getConfig();

const logger = {
  log: (...messages) => console.log(...messages),
  error: (...messages) => console.error(...messages),
};

async function main() {
  try {
    const deployer = (await ethers.getSigners())[0];
    const provider = ethers.provider;
    const multi = new MultiCall(provider);

    const inputs = [
      { interface: ConfigStorage__factory.abi, target: config.storages.config, function: "getCollateralTokens", args: [] },
      { interface: ConfigStorage__factory.abi, target: config.storages.config, function: "getHlpTokens", args: [] },
      { interface: ConfigStorage__factory.abi, target: config.storages.config, function: "getHlpAssetIds", args: [] },
      { interface: ConfigStorage__factory.abi, target: config.storages.config, function: "weth", args: [] },
    ];

    const [, [collateralTokens, hlpTokenMembers, hlpAssetIds, weth]] = await multi.multiCall(inputs as any);

    logger.log("Collateral Tokens:", collateralTokens);
    logger.log("HLP Token Members:", hlpTokenMembers);
    logger.log("HLP Asset IDs:", hlpAssetIds);
    logger.log("WETH:", weth);

    logger.log("Deployment validation passed!");
  } catch (error) {
    logger.error("Error during deployment:", error);
    process.exitCode = 1;
  }
}

main();
