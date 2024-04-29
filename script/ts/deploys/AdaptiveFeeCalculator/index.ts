import { ethers, run, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const k1 = 12500;
  const k2 = 50;

  console.log(`[deploys/AdaptiveFeeCalculator] Deploying AdaptiveFeeCalculator Contract`);
  const AdaptiveFeeCalculator = await ethers.getContractFactory("AdaptiveFeeCalculator", deployer);
  const adaptiveFeeCalculator = await AdaptiveFeeCalculator.deploy(k1, k2);
  await adaptiveFeeCalculator.deployed();
  console.log(`[deploys/AdaptiveFeeCalculator] Deployed at: ${adaptiveFeeCalculator.address}`);

  config.adaptiveFeeCalculator = adaptiveFeeCalculator.address;
  writeConfigFile(config);

  console.log(`[deploys/AdaptiveFeeCalculator] Verify contract on Tenderly`);
  await tenderly.verify({
    address: adaptiveFeeCalculator.address,
    name: "AdaptiveFeeCalculator",
  });

  console.log(`[deploys/AdaptiveFeeCalculator] Verify contract on Etherscan`);
  await run("verify:verify", {
    address: adaptiveFeeCalculator.address,
    constructorArguments: [k1, k2],
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
