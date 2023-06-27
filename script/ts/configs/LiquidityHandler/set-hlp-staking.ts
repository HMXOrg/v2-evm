import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  IPyth__factory,
  LimitTradeHandler__factory,
  LiquidityHandler__factory,
  MockPyth__factory,
  PythAdapter__factory,
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log("> LiquidityHandler: Set HLP Staking...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  await (await handler.setHlpStaking(config.staking.hlp)).wait();
  console.log("> LiquidityHandler: Set HLP Staking success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
