import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying UnsafeEcoPythCalldataBuilder2 Contract`);
  const UnsafeEcoPythCalldataBuilder2 = await ethers.getContractFactory("UnsafeEcoPythCalldataBuilder2", deployer);
  const unsafeEcoPythCalldataBuilder2 = await UnsafeEcoPythCalldataBuilder2.deploy(
    config.oracles.ecoPyth2,
    config.oracles.onChainPriceLens
  );
  await unsafeEcoPythCalldataBuilder2.deployed();
  console.log(`Deployed at: ${unsafeEcoPythCalldataBuilder2.address}`);

  config.oracles.unsafeEcoPythCalldataBuilder2 = unsafeEcoPythCalldataBuilder2.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: unsafeEcoPythCalldataBuilder2.address,
    name: "UnsafeEcoPythCalldataBuilder2",
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
