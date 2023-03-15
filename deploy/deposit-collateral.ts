import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { CrossMarginHandler__factory, ERC20__factory } from "../typechain";
import { getConfig } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  const token = ERC20__factory.connect(config.tokens.bad, deployer);
  const decimals = await token.decimals()
  const allowance = await token.allowance(deployer.address, crossMarginHandler.address);
  if (allowance.eq(0)) await (await token.approve(crossMarginHandler.address, ethers.constants.MaxUint256)).wait();

  await (
    await crossMarginHandler.depositCollateral(
      deployer.address,
      0,
      token.address,
      ethers.utils.parseUnits("5.968496893699999962", decimals),
      // ethers.utils.parseUnits("0.3131", 18),
      {
        gasLimit: 20000000,
      }
    )
  ).wait();
};

export default func;
func.tags = ["DepositCollateral"];
