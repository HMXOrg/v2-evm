import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying UnsafeEcoPythCalldataBuilder Contract`);
  const UnsafeEcoPythCalldataBuilder = await ethers.getContractFactory("UnsafeEcoPythCalldataBuilder", deployer);
  const unsafeEcoPythCalldataBuilder = await UnsafeEcoPythCalldataBuilder.deploy(
    config.oracles.ecoPyth2,
    config.vendors.gmx.glpManager,
    config.tokens.sglp
  );
  await unsafeEcoPythCalldataBuilder.deployed();
  console.log(`Deployed at: ${unsafeEcoPythCalldataBuilder.address}`);

  config.oracles.unsafeEcoPythCalldataBuilder = unsafeEcoPythCalldataBuilder.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: unsafeEcoPythCalldataBuilder.address,
    name: "UnsafeEcoPythCalldataBuilder",
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
