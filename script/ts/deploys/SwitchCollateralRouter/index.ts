import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("SwitchCollateralRouter", deployer);

  await contract.deployed();
  console.log(`[deploys/SwitchCollateralRouter] Deploying SwitchCollateralRouter Contract`);
  console.log(`[deploys/SwitchCollateralRouter] Deployed at: ${contract.address}`);

  config.extension.switchCollateralRouter = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "SwitchCollateralRouter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
