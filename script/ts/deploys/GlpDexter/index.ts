import { ethers, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract(
    "GlpDexter",
    [
      config.tokens.weth,
      config.tokens.sglp,
      config.vendors.gmx.glpManager,
      config.vendors.gmx.gmxVault,
      config.vendors.gmx.rewardRouterV2,
    ],
    deployer
  );

  await contract.deployed();
  console.log(`[deploys/GlpDexter] Deploying GlpDexter Contract`);
  console.log(`[deploys/GlpDexter] Deployed at: ${contract.address}`);

  config.extension.dexter.glp = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "GlpDexter",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
