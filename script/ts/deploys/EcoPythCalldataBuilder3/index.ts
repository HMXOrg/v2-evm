import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`[deploys/EcoPythCalldataBuilder3] Deploying EcoPythCalldataBuilder3 Contract`);
  const Contract = await ethers.getContractFactory("EcoPythCalldataBuilder3", deployer);
  const contract = await Contract.deploy(
    config.oracles.ecoPyth2,
    config.oracles.onChainPriceLens,
    config.oracles.calcPriceLens
  );
  await contract.deployed();
  console.log(`[deploys/EcoPythCalldataBuilder3] Deployed at: ${contract.address}`);

  config.oracles.ecoPythCalldataBuilder3 = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
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
