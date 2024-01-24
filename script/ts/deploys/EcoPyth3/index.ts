import { ethers, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { EcoPyth3__factory } from "../../../../typechain";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying EcoPyth3 Contract`);
  const Ecopyth3 = new EcoPyth3__factory(deployer);
  const ecoPyth3 = await Ecopyth3.deploy();
  await ecoPyth3.deployed();
  console.log(`Deployed at: ${ecoPyth3.address}`);

  config.oracles.ecoPyth3 = ecoPyth3.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: ecoPyth3.address,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
