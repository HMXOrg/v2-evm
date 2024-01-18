import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const k1 = 12500;
  const k2 = 50;

  console.log(`Deploying AdaptiveFeeCalculator Contract`);
  const AdaptiveFeeCalculator = await ethers.getContractFactory("AdaptiveFeeCalculator", deployer);
  const adaptiveFeeCalculator = await AdaptiveFeeCalculator.deploy(k1, k2);
  await adaptiveFeeCalculator.deployed();
  console.log(`Deployed at: ${adaptiveFeeCalculator.address}`);

  config.adaptiveFeeCalculator = adaptiveFeeCalculator.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: adaptiveFeeCalculator.address,
    name: "AdaptiveFeeCalculator",
  });
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
