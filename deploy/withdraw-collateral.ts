import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { CrossMarginHandler__factory, ERC20__factory, IPyth__factory } from "../typechain";
import { getConfig } from "./utils/config";
import { getPriceData } from "./utils/pyth";

const BigNumber = ethers.BigNumber;
const config = getConfig();
const subAccountId = 1;

const priceIds = [
  "0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6", // ETH/USD
  "0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b", // BTC/USD
  "0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722", // USDC/USD
  "0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588", // USDT/USD
  "0x87a67534df591d2dd5ec577ab3c75668a8e3d35e92e27bf29d9e2e52df8de412", // DAI/USD
];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const address = BigNumber.from(deployer.address).xor(subAccountId).toHexString();

  const pyth = IPyth__factory.connect(config.oracle.pyth, deployer);
  const priceData = await getPriceData(priceIds);
  const updateFee = await pyth.getUpdateFee(priceData);
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  const token = ERC20__factory.connect(config.tokens.usdc, deployer);

  await (await crossMarginHandler.withdrawCollateral(
    address,
    subAccountId,
    token.address,
    ethers.utils.parseUnits("50000", 6),
    priceData,
    { gasLimit: 20000000, value: updateFee }
  )).wait();
};

export default func;
func.tags = ["WithdrawCollateral"];
