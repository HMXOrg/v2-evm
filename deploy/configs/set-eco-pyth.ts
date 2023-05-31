import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import { IPyth__factory, MockPyth__factory, PythAdapter__factory } from "../../typechain";
import { getConfig } from "../utils/config";

const wethPriceId = "0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6";
const wbtcPriceId = "0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b";
const usdcPriceId = "0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722";
const usdtPriceId = "0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588";
const daiPriceId = "0x87a67534df591d2dd5ec577ab3c75668a8e3d35e92e27bf29d9e2e52df8de412";
const applePriceId = "0xafcc9a5bb5eefd55e12b6f0b4c8e6bccf72b785134ee232a5d175afd082e8832";
const jpyPriceId = "0x20a938f54b68f1f2ef18ea0328f6dd0747f8ea11486d22b021e83a900be89776";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const addresses = [
    config.oracles.pythAdapter,
    // config.handlers.crossMargin,
    // config.handlers.limitTrade,
    // config.handlers.liquidity,
    // config.handlers.bot,
  ];
  await Promise.all(
    addresses.map(async (each) => {
      const pythAdapter = PythAdapter__factory.connect(each, deployer);
      return pythAdapter.setPyth(config.oracles.ecoPyth);
    })
  );
  console.log("> Set Eco Pyth success!");
};
export default func;
func.tags = ["SetEcoPyth"];
