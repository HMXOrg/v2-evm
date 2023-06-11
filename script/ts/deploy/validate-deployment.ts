import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { ConfigStorage__factory } from "../../../typechain";
import { getConfig } from "../utils/config";
import { MultiCall } from "@indexed-finance/multicall";
import { strict as assert } from "assert";

const formatUnits = ethers.utils.formatUnits;
const parseUnits = ethers.utils.parseUnits;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const provider = ethers.provider;
  const multi = new MultiCall(provider);

  const inputs = [
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "getCollateralTokens",
      args: [],
    },
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "getHlpTokens",
      args: [],
    },
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "getHlpAssetIds",
      args: [],
    },
    {
      interface: ConfigStorage__factory.abi,
      target: config.storages.config,
      function: "weth",
      args: [],
    },
  ];
  const [, [collateralTokens, hlpTokenMembers, hlpAssetIds, weth]] = await multi.multiCall(inputs as any);

  console.log(collateralTokens);

  console.log(hlpTokenMembers);

  console.log(hlpAssetIds);

  console.log(weth);
  console.log("Deployment validation passed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
