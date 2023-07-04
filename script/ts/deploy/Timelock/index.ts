import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { Timelock__factory } from "../../../../typechain";

async function main() {
  const MINIMUM_DELAY = 86400;

  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const Timelock = new Timelock__factory(deployer);

  console.log(`[deploy/Timelock] Deploying Timelock`);
  const timelock = await Timelock.deploy(deployer.address, MINIMUM_DELAY);
  await timelock.deployTransaction.wait();
  console.log(`[deploy/Timelock] Deployed at: ${timelock.address}`);

  config.timelock = timelock.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: timelock.address,
    name: "Timelock",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
