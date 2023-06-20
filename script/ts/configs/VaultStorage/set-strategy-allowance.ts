import { ethers } from "hardhat";
import {
  ConfigStorage__factory,
  EcoPyth__factory,
  PythAdapter__factory,
  VaultStorage__factory,
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const token = config.tokens.sglp;
const strategy = config.strategies.stakedGlpStrategy;
const target = config.yieldSources.gmx.rewardTracker;

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);

  console.log("> VaultStorage: Set Strategy Allowance...");
  await (await vaultStorage.setStrategyAllowance(token, strategy, target)).wait();
  console.log("> VaultStorage: Set Strategy Allowance success!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
