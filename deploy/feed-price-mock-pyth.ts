import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import { IPyth__factory, MockPyth__factory, PythAdapter__factory } from "../typechain";
import { getConfig } from "./utils/config";

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
  // https://xc-mainnet.pyth.network
  // https://xc-testnet.pyth.network
  const deployer = (await ethers.getSigners())[0];
  const connection = new EvmPriceServiceConnection("https://xc-testnet.pyth.network", {
    logger: console, // Providing logger will allow the connection to log its events.
  });

  const priceIds = [wethPriceId, wbtcPriceId, usdcPriceId, usdtPriceId, daiPriceId, applePriceId, jpyPriceId];

  const priceUpdates = [
    {
      id: wethPriceId,
      price: parseUnits("1900.02", 8),
      conf: parseUnits("0", 8),
      expo: -8,
      emaPrice: 0,
      emaConf: 0,
      publishTime: (new Date().valueOf() / 1000).toFixed(),
    },
    {
      id: wbtcPriceId,
      price: parseUnits("28309.12", 8),
      conf: parseUnits("0", 8),
      expo: -8,
      emaPrice: 0,
      emaConf: 0,
      publishTime: (new Date().valueOf() / 1000).toFixed(),
    },
    {
      id: usdcPriceId,
      price: parseUnits("1.00", 8),
      conf: parseUnits("0", 8),
      expo: -8,
      emaPrice: 0,
      emaConf: 0,
      publishTime: (new Date().valueOf() / 1000).toFixed(),
    },
    {
      id: usdtPriceId,
      price: parseUnits("1.00", 8),
      conf: parseUnits("0", 8),
      expo: -8,
      emaPrice: 0,
      emaConf: 0,
      publishTime: (new Date().valueOf() / 1000).toFixed(),
    },
    {
      id: daiPriceId,
      price: parseUnits("1.00", 8),
      conf: parseUnits("0", 8),
      expo: -8,
      emaPrice: 0,
      emaConf: 0,
      publishTime: (new Date().valueOf() / 1000).toFixed(),
    },
    {
      id: applePriceId,
      price: parseUnits("164.640", 8),
      conf: parseUnits("0", 8),
      expo: -8,
      emaPrice: 0,
      emaConf: 0,
      publishTime: (new Date().valueOf() / 1000).toFixed(),
    },
    {
      id: jpyPriceId,
      price: parseUnits("132.701", 8),
      conf: parseUnits("0", 8),
      expo: -8,
      emaPrice: 0,
      emaConf: 0,
      publishTime: (new Date().valueOf() / 1000).toFixed(),
    },
  ];

  const pyth = MockPyth__factory.connect(config.oracle.leanPyth, deployer);
  // const updateFee = 0;
  // const updateData = await priceUpdates.map(async (each) => {
  //   return await pyth.createPriceFeedUpdateData(
  //     each.id,
  //     each.price,
  //     each.conf,
  //     each.expo,
  //     each.emaPrice,
  //     each.emaConf,
  //     each.publishTime
  //   );
  // });
  // await (await pyth.updatePriceFeeds(updateData, { value: updateFee })).wait();
  console.log("> Feed Mock Price success!");
};
export default func;
func.tags = ["FeedPriceMockPyth"];
