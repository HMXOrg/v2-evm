import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import { IPyth__factory } from "../typechain";

const wethPriceId = "0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6";
const wbtcPriceId = "0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b";
const usdcPriceId = "0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722";
const usdtPriceId = "0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588";
const daiPriceId = "0x87a67534df591d2dd5ec577ab3c75668a8e3d35e92e27bf29d9e2e52df8de412";
const applePriceId = "0xafcc9a5bb5eefd55e12b6f0b4c8e6bccf72b785134ee232a5d175afd082e8832";
const jpyPriceId = "0x20a938f54b68f1f2ef18ea0328f6dd0747f8ea11486d22b021e83a900be89776";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // https://xc-mainnet.pyth.network
  // https://xc-testnet.pyth.network
  const deployer = (await ethers.getSigners())[0];
  const connection = new EvmPriceServiceConnection("https://xc-testnet.pyth.network", {
    logger: console, // Providing logger will allow the connection to log its events.
  });

  const priceIds = [wethPriceId, wbtcPriceId, usdcPriceId, usdtPriceId, daiPriceId, applePriceId, jpyPriceId];
  // console.log(priceIds);
  const priceFeeds = await connection.getLatestPriceFeeds(priceIds);
  // console.log(priceFeeds);
  // console.log(priceFeeds?.at(0)?.getPriceNoOlderThan(60));

  const updateData = await connection.getPriceFeedsUpdateData(priceIds);
  // console.log(updateData);

  const pyth = IPyth__factory.connect("0x939C0e902FF5B3F7BA666Cc8F6aC75EE76d3f900", deployer);
  // console.log(await pyth.getPriceUnsafe(priceIds[0]));
  const updateFee = await pyth.getUpdateFee(updateData);
  // console.log("updateFee", updateFee);
  await (await pyth.updatePriceFeeds(updateData, { value: updateFee })).wait();
};
export default func;
func.tags = ["FeedPricePyth"];
