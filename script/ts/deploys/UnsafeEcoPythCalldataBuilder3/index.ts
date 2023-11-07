import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying UnsafeEcoPythCalldataBuilder3 Contract`);
  const UnsafeEcoPythCalldataBuilder3 = await ethers.getContractFactory("UnsafeEcoPythCalldataBuilder3", deployer);
  const unsafeEcoPythCalldataBuilder3 = await UnsafeEcoPythCalldataBuilder3.deploy(
    config.oracles.ecoPyth2,
    config.oracles.onChainPriceLens,
    config.oracles.calcPriceLens,
    true
  );
  await unsafeEcoPythCalldataBuilder3.deployed();
  console.log(`Deployed at: ${unsafeEcoPythCalldataBuilder3.address}`);

  config.oracles.unsafeEcoPythCalldataBuilder3 = unsafeEcoPythCalldataBuilder3.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: unsafeEcoPythCalldataBuilder3.address,
    name: "UnsafeEcoPythCalldataBuilder3",
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
