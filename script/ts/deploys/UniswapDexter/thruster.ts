import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract(
    "UniswapDexter",
    [config.vendors.thruster!.permit2, config.vendors.thruster!.universalRouter],
    deployer
  );

  await contract.deployed();
  console.log(`[deploys/Dexter] Deploying UniswapDexter Contract`);
  console.log(`[deploys/Dexter] Deployed at: ${contract.address}`);

  config.extension.dexter.thruster = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: config.extension.dexter.thruster,
    constructorArguments: [config.vendors.thruster!.permit2, config.vendors.thruster!.universalRouter],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
