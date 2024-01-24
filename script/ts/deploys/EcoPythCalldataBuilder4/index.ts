import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`[deploys/EcoPythCalldataBuilder4] Deploying EcoPythCalldataBuilder4 Contract`);
  const Contract = await ethers.getContractFactory("EcoPythCalldataBuilder4", deployer);
  const contract = await Contract.deploy(
    config.oracles.ecoPyth2,
    config.oracles.onChainPriceLens,
    config.oracles.calcPriceLens,
    true
  );
  await contract.deployed();
  console.log(`[deploys/EcoPythCalldataBuilder4] Deployed at: ${contract.address}`);

  config.oracles.ecoPythCalldataBuilder4 = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: contract.address,
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
