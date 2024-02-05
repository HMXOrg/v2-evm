import { ethers } from "hardhat";
import { ConfigStorage__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const pnlCollateralFactor = 0.8 * 10000; // 0.8 Collateral Factor for Unrealized PnL

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("> ConfigStorage: Set PnL Factor...");
  await (await configStorage.setPnlFactor(pnlCollateralFactor)).wait();
  console.log("> ConfigStorage: Set PnL Factor success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
