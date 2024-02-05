import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const liquidationConfig = {
  liquidationFeeUSDE30: ethers.utils.parseUnits("5", 30),
};

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set Liquidation Config...");
  await (await configStorage.setLiquidationConfig(liquidationConfig)).wait();
  console.log("> ConfigStorage: Set Liquidation Config success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
