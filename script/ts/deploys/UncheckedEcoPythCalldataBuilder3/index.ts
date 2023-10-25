import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying UncheckedEcoPythCalldataBuilder3 Contract`);
  const UncheckedEcoPythCalldataBuilder3 = await ethers.getContractFactory(
    "UncheckedEcoPythCalldataBuilder3",
    deployer
  );
  const uncheckedEcoPythCalldataBuilder3 = await UncheckedEcoPythCalldataBuilder3.deploy(
    config.oracles.ecoPyth2,
    config.oracles.onChainPriceLens,
    config.oracles.calcPriceLens,
    true
  );
  await uncheckedEcoPythCalldataBuilder3.deployed();
  console.log(`Deployed at: ${uncheckedEcoPythCalldataBuilder3.address}`);

  config.oracles.uncheckedEcoPythCalldataBuilder3 = uncheckedEcoPythCalldataBuilder3.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: uncheckedEcoPythCalldataBuilder3.address,
    name: "UncheckedEcoPythCalldataBuilder3",
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
