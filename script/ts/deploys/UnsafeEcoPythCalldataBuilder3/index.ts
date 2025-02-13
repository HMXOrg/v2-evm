import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`[deploys/EcoPythCalldataBuilder] Deploying UnsafeEcoPythCalldataBuilder3 Contract`);
  const UnsafeEcoPythCalldataBuilder3 = await ethers.getContractFactory("UnsafeEcoPythCalldataBuilder3", deployer);
  const unsafeEcoPythCalldataBuilder3 = await UnsafeEcoPythCalldataBuilder3.deploy(
    config.oracles.ecoPyth2!,
    config.oracles.onChainPriceLens,
    config.oracles.calcPriceLens
  );
  await unsafeEcoPythCalldataBuilder3.deployed();
  console.log(`[deploys/EcoPythCalldataBuilder] Deployed at: ${unsafeEcoPythCalldataBuilder3.address}`);

  config.oracles.unsafeEcoPythCalldataBuilder3 = unsafeEcoPythCalldataBuilder3.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: unsafeEcoPythCalldataBuilder3.address,
    constructorArguments: [config.oracles.ecoPyth2, config.oracles.onChainPriceLens, config.oracles.calcPriceLens],
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
