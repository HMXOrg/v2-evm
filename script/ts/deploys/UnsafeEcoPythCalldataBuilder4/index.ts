import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`[deploys/EcoPythCalldataBuilder] Deploying UnsafeEcoPythCalldataBuilder4 Contract`);
  const UnsafeEcoPythCalldataBuilder4 = await ethers.getContractFactory("UnsafeEcoPythCalldataBuilder4", deployer);
  const unsafeEcoPythCalldataBuilder4 = await UnsafeEcoPythCalldataBuilder4.deploy(
    config.oracles.ecoPyth2,
    config.oracles.onChainPriceLens,
    config.oracles.calcPriceLens,
    true
  );
  await unsafeEcoPythCalldataBuilder4.deployed();
  console.log(`[deploys/EcoPythCalldataBuilder] Deployed at: ${unsafeEcoPythCalldataBuilder4.address}`);

  config.oracles.unsafeEcoPythCalldataBuilder4 = unsafeEcoPythCalldataBuilder4.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: unsafeEcoPythCalldataBuilder4.address,
    constructorArguments: [],
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
