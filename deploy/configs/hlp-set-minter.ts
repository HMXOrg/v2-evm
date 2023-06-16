import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EcoPyth__factory, PLPv2__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const minter = config.services.liquidity;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const hlp = PLPv2__factory.connect(config.tokens.hlp, deployer);

  console.log("> HLP Set Minter...");
  await (await hlp.setMinter(minter, true)).wait();
  console.log("> HLP Set Minter success!");
};
export default func;
func.tags = ["HLPSetMinter"];
