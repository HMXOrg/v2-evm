import { ethers, run } from "hardhat";
import { loadConfig, writeConfigFile } from "../../utils/config";
import { Erc4626Dexter__factory } from "../../../../typechain";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);
  const deployer = (await ethers.getSigners())[0];
  const Erc4626Dexter = new Erc4626Dexter__factory(deployer);

  console.log(`[deploys/Erc4626Dexter] Deploying Erc4626Dexter Contract`);
  const contract = await Erc4626Dexter.deploy();
  console.log(`[deploys/Erc4626Dexter] Deployed at: ${contract.address}`);

  config.extension.dexter.erc4626 = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
